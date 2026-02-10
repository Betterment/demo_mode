# frozen_string_literal: true

module DemoMode
  class SequenceTracker
    THREAD_KEY = :demo_mode_sequence_entries

    class << self
      def track
        Thread.current[THREAD_KEY] = []
        yield
        Thread.current[THREAD_KEY].dup
      ensure
        Thread.current[THREAD_KEY] = nil
      end

      def record(klass, attribute, value)
        return unless tracking?

        entries << {
          class: klass.to_s,
          attribute: attribute.to_s,
          value: serialize_value(value)
        }
      end

      def tracking?
        Thread.current[THREAD_KEY].is_a?(Array)
      end

      private

      def entries
        Thread.current[THREAD_KEY]
      end

      def serialize_value(value)
        case value
        when String, Numeric, TrueClass, FalseClass, NilClass
          value
        when Date, Time, DateTime
          value.iso8601
        else
          value.to_s
        end
      end
    end
  end
end
