# frozen_string_literal: true

class CleverSequence
  module InMemoryBackend
    class << self
      def nextval(klass, attribute, block)
        key = [klass.name, attribute.to_s]
        sequence_state[key] = current_value(klass, attribute, block, key) + 1
      end

      def reset!
        @sequence_state = {}
      end

      def starting_value(klass, attribute, block)
        column_name = resolve_column_name(klass, attribute)

        if column_exists?(klass, column_name)
          LowerBoundFinder.new(klass, column_name, block).lower_bound
        else
          0
        end
      end

      def with_sequence_adjustment(**)
        # No-op for InMemoryBackend. After reset!, nextval already
        # recalculates from the database via starting_value/LowerBoundFinder,
        # which finds the correct lower bound past existing data.
        yield
      end

      def sequence_state
        @sequence_state ||= {}
      end

      private

      def current_value(klass, attribute, block, key)
        sequence_state[key] || starting_value(klass, attribute, block)
      end

      def resolve_column_name(klass, attribute)
        klass.attribute_aliases[attribute.to_s] || attribute.to_s
      end

      def column_exists?(klass, column_name)
        klass && klass.column_names.include?(column_name)
      end
    end
  end
end
