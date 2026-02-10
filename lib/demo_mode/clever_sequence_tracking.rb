# frozen_string_literal: true

module DemoMode
  module CleverSequenceTracking
    def next(klass, name)
      result = super
      DemoMode::SequenceTracker.record(klass, name, result)
      result
    end
  end
end
