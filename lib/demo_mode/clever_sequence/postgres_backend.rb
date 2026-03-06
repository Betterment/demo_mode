# frozen_string_literal: true

require 'monitor'

class CleverSequence
  module PostgresBackend
    SEQUENCE_PREFIX = 'cs_'

    class SequenceNotFoundError < StandardError
      attr_reader :sequence_name, :klass, :attribute

      def initialize(sequence_name:, klass:, attribute:)
        @sequence_name = sequence_name
        @klass = klass
        @attribute = attribute

        super(
          "Sequence '#{sequence_name}' not found for #{klass.name}##{attribute}. "
        )
      end
    end

    module SequenceResult
      Exists = Data.define(:sequence_name)
      Missing = Data.define(:sequence_name, :klass, :attribute, :calculated_start_value)
    end

    # Initialized eagerly at load time (single-threaded), so no race on creation.
    # Monitor is reentrant, allowing nextval -> sequence_exists? nesting.
    @sequence_monitor = Monitor.new

    class << self
      def reset!
        @sequence_cache = {}
      end

      def starting_value(klass, attribute, block)
        calculate_sequence_value(klass, attribute, block)
      end

      def with_sequence_adjustment
        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Enabling sequence adjustment for retry")
        Thread.current[:clever_sequence_adjust_sequences_enabled] = true
        yield
      ensure
        Thread.current[:clever_sequence_adjust_sequences_enabled] = false
        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Disabled sequence adjustment")
      end

      def nextval(klass, attribute, block)
        @sequence_monitor.synchronize do
          name = sequence_name(klass, attribute)
          Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] nextval called for #{klass.name}##{attribute} (sequence: #{name})")

          if sequence_exists?(name)
            # On first use with adjustment enabled, ensure sequence is past existing data
            if adjust_sequences_enabled? && !sequence_cache[name].is_a?(SequenceResult::Exists)
              Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence adjustment enabled and #{name} not yet adjusted, adjusting now for #{klass.name}##{attribute}")
              adjust_sequence_if_needed(name, klass, attribute, block)
            end
            sequence_cache[name] = SequenceResult::Exists.new(name)

            result = ActiveRecord::Base.connection.execute(
              "SELECT nextval('#{name}')",
            )
            value = result.first['nextval'].to_i
            Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] nextval for #{klass.name}##{attribute} returned #{value} from postgres sequence #{name}")
            value
          else
            # Check if we already have this sequence cached as Missing
            cached = sequence_cache[name]

            if cached.is_a?(SequenceResult::Missing)
              # Increment from cached value instead of recalculating from DB
              # This handles the case where transactions are rolled back but we
              # need to continue generating unique values
              next_value = cached.calculated_start_value + 1
              Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{name} missing (cached), incrementing from cached value #{cached.calculated_start_value} to #{next_value} for #{klass.name}##{attribute}")
              sequence_cache[name] = SequenceResult::Missing.new(
                sequence_name: name,
                klass: klass,
                attribute: attribute,
                calculated_start_value: next_value,
              )
            else
              # First time seeing this missing sequence - calculate from DB
              start_value = calculate_sequence_value(klass, attribute, block)
              next_value = start_value + 1
              Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{name} missing (first encounter), calculated start_value=#{start_value}, returning next_value=#{next_value} for #{klass.name}##{attribute}")
              sequence_cache[name] = SequenceResult::Missing.new(
                sequence_name: name,
                klass: klass,
                attribute: attribute,
                calculated_start_value: next_value,
              )
            end

            if CleverSequence.enforce_sequences_exist
              Rails.logger.warn("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Raising SequenceNotFoundError for #{klass.name}##{attribute} (sequence: #{name}, enforce_sequences_exist is enabled)")
              raise SequenceNotFoundError.new(
                sequence_name: name,
                klass: klass,
                attribute: attribute,
              )
            else
              Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] nextval for #{klass.name}##{attribute} returning #{next_value} (fallback, sequence #{name} does not exist)")
              next_value
            end
          end
        end
      end

      def sequence_name(klass, attribute)
        table = klass.table_name.gsub(/[^a-z0-9_]/i, '_')
        attr = attribute.to_s.gsub(/[^a-z0-9_]/i, '_')
        # Handle PostgreSQL identifier limit:
        limit = (63 - SEQUENCE_PREFIX.length) / 2
        # Lowercase to avoid PostgreSQL case-sensitivity issues with unquoted identifiers
        "#{SEQUENCE_PREFIX}#{table[0, limit]}_#{attr[0, limit]}".downcase
      end

      def sequence_cache
        @sequence_cache ||= {}
      end

      def clear_sequence_cache!
        @sequence_monitor.synchronize do
          # Preserve Missing entries since those are needed for sequence discovery
          # Only clear Exists entries so sequences get re-checked and potentially adjusted
          existing_keys = sequence_cache.select { |_, v| v.is_a?(SequenceResult::Exists) }.keys
          Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Clearing sequence cache: removing #{existing_keys.size} Exists entries (#{existing_keys.join(', ')}), preserving #{sequence_cache.size - existing_keys.size} Missing entries")
          @sequence_cache = sequence_cache.select { |_, v| v.is_a?(SequenceResult::Missing) }
        end
      end

      private

      def adjust_sequences_enabled?
        Thread.current[:clever_sequence_adjust_sequences_enabled]
      end

      def sequence_exists?(sequence_name)
        if sequence_cache.key?(sequence_name)
          case sequence_cache[sequence_name]
          when SequenceResult::Exists
            Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{sequence_name} exists (cached)")
            return true
          else
            Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{sequence_name} does not exist (cached as #{sequence_cache[sequence_name].class.name})")
            return false
          end
        end

        exists = ActiveRecord::Base.connection.execute(
          "SELECT 1 FROM information_schema.sequences WHERE sequence_name = '#{sequence_name}' LIMIT 1",
        ).any?
        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{sequence_name} #{exists ? 'found' : 'not found'} in information_schema")
        exists
      end

      def calculate_sequence_value(klass, attribute, block)
        column_name = klass.attribute_aliases.fetch(attribute.to_s, attribute.to_s)
        unless klass.column_names.include?(column_name)
          Rails.logger.warn("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Column #{column_name} not found on #{klass.name}, returning 0 for sequence value calculation")
          return 0
        end

        value = ActiveRecord::Base.with_transactional_lock("lower-bound-#{klass}-#{column_name}") do
          LowerBoundFinder.new(klass, column_name, block).lower_bound
        end
        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Calculated sequence value for #{klass.name}##{attribute} (column: #{column_name}): #{value}")
        value
      end

      def adjust_sequence_if_needed(sequence_name, klass, attribute, block)
        max_value = calculate_sequence_value(klass, attribute, block)
        if max_value < 1
          Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] No adjustment needed for sequence #{sequence_name} (#{klass.name}##{attribute}), max_value=#{max_value}")
          return
        end

        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Adjusting sequence #{sequence_name} for #{klass.name}##{attribute} to at least #{max_value}")
        # setval sets the sequence's last_value. With the default 3rd argument (true),
        # the next nextval() will return last_value + 1.
        # We only want to advance (never go backwards), so we use GREATEST.
        result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
          SELECT setval('#{sequence_name}', GREATEST(#{max_value}, (SELECT last_value FROM #{sequence_name})))
        SQL
        new_last_value = result.first['setval'].to_i
        Rails.logger.info("[DemoMode][thread:#{Thread.current.name || Thread.current.object_id}] Sequence #{sequence_name} adjusted, new last_value=#{new_last_value} (next nextval will return #{new_last_value + 1})")
      end
    end
  end
end
