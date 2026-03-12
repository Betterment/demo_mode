# frozen_string_literal: true

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

    class << self
      def reset!
        Thread.current[:clever_sequence_cache] = {}
      end

      def starting_value(klass, attribute, block)
        calculate_sequence_value(klass, attribute, block)
      end

      def with_sequence_adjustment(last_values: {})
        previous = Thread.current[:clever_sequence_adjustment_enabled]
        previous_last_values = Thread.current[:clever_sequence_last_values]
        log "[DemoMode] Enabling sequence adjustment for retry"
        Thread.current[:clever_sequence_adjustment_enabled] = true
        Thread.current[:clever_sequence_last_values] = last_values
        yield
      ensure
        Thread.current[:clever_sequence_adjustment_enabled] = previous
        Thread.current[:clever_sequence_last_values] = previous_last_values
        log "[DemoMode] Disabled sequence adjustment"
      end

      def nextval(klass, attribute, block)
        name = sequence_name(klass, attribute)
        log "[DemoMode] nextval called for #{klass.name}##{attribute} (sequence: #{name})"

        if sequence_exists?(name)
          nextval_from_sequence(name, klass, attribute, block)
        else
          nextval_without_sequence(name, klass, attribute, block)
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
        Thread.current[:clever_sequence_cache] ||= {}
      end

      private

      def log(message, level: DemoMode.log_level)
        Rails.logger.public_send(level, message)
      end

      def nextval_from_sequence(name, klass, attribute, block)
        # On first use with adjustment enabled, ensure sequence is past existing data
        if adjust_sequences_enabled? && !sequence_cache[name].is_a?(SequenceResult::Exists)
          log "[DemoMode] Sequence adjustment enabled, adjusting #{name}"
          adjust_sequence_if_needed(name, klass, attribute, block)
        end
        sequence_cache[name] = SequenceResult::Exists.new(name)

        result = ActiveRecord::Base.connection.execute(
          "SELECT nextval('#{name}')",
        )
        value = result.first['nextval'].to_i
        log "[DemoMode] nextval for #{klass.name}##{attribute} returned #{value}"
        value
      end

      def nextval_without_sequence(name, klass, attribute, block)
        next_value = calculate_next_missing_value(name, klass, attribute, block)

        if CleverSequence.enforce_sequences_exist
          log "[DemoMode] Raising SequenceNotFoundError for #{name}", level: :warn
          raise SequenceNotFoundError.new(
            sequence_name: name, klass: klass, attribute: attribute,
          )
        else
          log "[DemoMode] nextval returning #{next_value} (fallback, #{name} missing)"
          next_value
        end
      end

      def calculate_next_missing_value(name, klass, attribute, block)
        cached = sequence_cache[name]

        next_value = if cached.is_a?(SequenceResult::Missing)
          cached.calculated_start_value + 1
        else
          calculate_sequence_value(klass, attribute, block) + 1
        end

        sequence_cache[name] = SequenceResult::Missing.new(
          sequence_name: name, klass: klass,
          attribute: attribute, calculated_start_value: next_value
        )

        next_value
      end

      def adjust_sequences_enabled?
        Thread.current[:clever_sequence_adjustment_enabled]
      end

      def sequence_exists?(sequence_name)
        if sequence_cache.key?(sequence_name)
          exists = sequence_cache[sequence_name].is_a?(SequenceResult::Exists)
          log "[DemoMode] Sequence #{sequence_name} #{exists ? 'exists' : 'missing'} (cached)"
          return exists
        end

        exists = ActiveRecord::Base.connection.execute(
          "SELECT 1 FROM information_schema.sequences " \
          "WHERE sequence_name = '#{sequence_name}' LIMIT 1",
        ).any?
        log "[DemoMode] Sequence #{sequence_name} #{exists ? 'found' : 'not found'}"
        exists
      end

      def calculate_sequence_value(klass, attribute, block, hint: nil)
        column_name = klass.attribute_aliases.fetch(attribute.to_s, attribute.to_s)
        unless klass.column_names.include?(column_name)
          log "[DemoMode] Column #{column_name} not found on #{klass.name}", level: :warn
          return 0
        end

        value = ActiveRecord::Base.with_transactional_lock("lower-bound-#{klass}-#{column_name}") do
          LowerBoundFinder.new(klass, column_name, block).lower_bound(hint:)
        end
        log "[DemoMode] Calculated sequence value for #{klass.name}##{attribute}: #{value} (hint: #{hint || 'none'})"
        value
      end

      def hint_for(klass, attribute)
        last_values = Thread.current[:clever_sequence_last_values]
        last_values && last_values[[klass.name, attribute.to_s]]
      end

      def adjust_sequence_if_needed(sequence_name, klass, attribute, block)
        ActiveRecord::Base.with_transactional_lock("adjust-sequence-#{sequence_name}") do
          hint = hint_for(klass, attribute)
          max_value = calculate_sequence_value(klass, attribute, block, hint:)
          if max_value < 1
            log "[DemoMode] No adjustment needed for #{sequence_name}"
            return
          end

          log "[DemoMode] Adjusting #{sequence_name} to at least #{max_value}"
          # setval sets the sequence's last_value. With the default 3rd argument (true),
          # the next nextval() will return last_value + 1.
          # We only want to advance (never go backwards), so we use GREATEST.
          result = ActiveRecord::Base.connection.execute(<<~SQL.squish)
            SELECT setval('#{sequence_name}',
              GREATEST(#{max_value}, (SELECT last_value FROM #{sequence_name})))
          SQL
          new_last_value = result.first['setval'].to_i
          log "[DemoMode] #{sequence_name} adjusted to #{new_last_value}"
        end
      end
    end
  end
end
