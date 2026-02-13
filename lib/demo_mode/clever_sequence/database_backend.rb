# frozen_string_literal: true

class CleverSequence
  module DatabaseBackend
    SEQUENCE_PREFIX = 'clever_seq_'

    THROW_IF_SEQUENCE_NOT_FOUND = true

    class SequenceNotFoundError < StandardError
      attr_reader :sequence_name, :klass, :attribute

      def initialize(sequence_name:, klass:, attribute:)
        @sequence_name = sequence_name
        @klass = klass
        @attribute = attribute
        super("Sequence '#{sequence_name}' not found for #{klass.name}##{attribute}. Run migration to create sequences.")
      end
    end

    class << self
      def nextval(klass, attribute, block)
        name = sequence_name(klass, attribute)

        result = ActiveRecord::Base.connection.execute(
          "SELECT nextval('#{name}')",
        )
        result.first['nextval'].to_i
      rescue ActiveRecord::StatementInvalid => e
        if sequence_not_exists_error?(e)
          return calculate_sequence_value(klass, attribute, block) + 1 unless THROW_IF_SEQUENCE_NOT_FOUND

          raise SequenceNotFoundError.new(sequence_name: name, klass: klass, attribute: attribute)
        else
          raise # Re-raise other database errors
        end
      end

      def sequence_name(klass, attribute)
        table = klass.table_name.gsub(/[^a-z0-9_]/i, '_')
        attr = attribute.to_s.gsub(/[^a-z0-9_]/i, '_')
        "#{SEQUENCE_PREFIX}#{table}_#{attr}"[0, 63] # PostgreSQL identifier limit
      end

      private

      def sequence_not_exists_error?(error)
        error.cause.is_a?(PG::UndefinedTable) # todo: Nathan tell us if this is right
      end

      def calculate_sequence_value(klass, attribute, block)
        column_name = klass.attribute_aliases[attribute.to_s] || attribute.to_s
        return 0 unless klass.column_names.include?(column_name)

        LowerBoundFinder.new(klass, column_name, block).lower_bound
      end
    end
  end
end
