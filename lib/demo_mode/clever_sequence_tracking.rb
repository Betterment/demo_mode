# frozen_string_literal: true

module DemoMode
  # Tracks class method calls: CleverSequence.next(klass, name)
  module CleverSequenceClassTracking
    def next(klass, name)
      result = super
      DemoMode::SequenceTracker.record(klass, name, result)
      result
    end
  end

  # Tracks instance method calls: sequence.next (used by FactoryBot)
  module CleverSequenceInstanceTracking
    def next
      result = super
      DemoMode::SequenceTracker.record(klass, attribute, result) if klass
      result
    end
  end
end
