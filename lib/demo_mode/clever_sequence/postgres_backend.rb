# frozen_string_literal: true

class CleverSequence
  module PostgresBackend
    SEQUENCE_PREFIX = 'clever_seq_'

    class SequenceNotFoundError < StandardError
      attr_reader :sequence_name, :klass, :attribute, :calculated_start_value

      def initialize(sequence_name:, klass:, attribute:, calculated_start_value:)
        @sequence_name = sequence_name
        @klass = klass
        @attribute = attribute
        @calculated_start_value = calculated_start_value
        super(
          "Sequence '#{sequence_name}' not found for #{klass.name}##{attribute}. " \
          "Calculated start value: #{calculated_start_value}. " \
        )
      end
    end

    class << self
      def nextval(klass, attribute, block, throw_if_sequence_not_found: true)
        name = sequence_name(klass, attribute)

        unless sequence_exists?(name)
          start_value = calculate_sequence_value(klass, attribute, block)

          ActiveSupport::Notifications.instrument(
            'clever_sequence.sequence_not_found',
            sequence_name: name,
            klass: klass,
            attribute: attribute,
            start_value: start_value,
          )

          if throw_if_sequence_not_found
            raise SequenceNotFoundError.new(
              sequence_name: name,
              klass: klass,
              attribute: attribute,
              calculated_start_value: start_value + 1,
            )
          else
            return start_value + 1
          end
        end

        # Sequence exists, use it
        result = ActiveRecord::Base.connection.execute(
          "SELECT nextval('#{name}')",
        )
        result.first['nextval'].to_i
      end

      def sequence_name(klass, attribute)
        table = klass.table_name.gsub(/[^a-z0-9_]/i, '_')
        attr = attribute.to_s.gsub(/[^a-z0-9_]/i, '_')
        "#{SEQUENCE_PREFIX}#{table}_#{attr}"[0, 63] # PostgreSQL identifier limit
      end

      private

      def sequence_exists?(sequence_name)
        @sequence_cache ||= {}

        return true if @sequence_cache[sequence_name] == true

        result = ActiveRecord::Base.connection.execute(
          "SELECT 1 FROM information_schema.sequences WHERE sequence_name = '#{sequence_name}'",
        )

        exists = result.any?

        @sequence_cache[sequence_name] = true if exists

        exists
      end

      def calculate_sequence_value(klass, attribute, block)
        column_name = klass.attribute_aliases[attribute.to_s] || attribute.to_s
        return 0 unless klass.column_names.include?(column_name)

        LowerBoundFinder.new(klass, column_name, block).lower_bound
      end
    end
  end
end
