# frozen_string_literal: true

module FactoryBot
  class DefinitionProxy
    def clever_sequence(name, &)
      sequence = CleverSequence.new(name, &)
      add_attribute(name) { sequence.with_class(@instance&.class).next }
    end

    alias sequence clever_sequence
  end
end

module DemoMode
  module FactoryBotExt
    def around_each(&block)
      @around_each ||= ->(&blk) { blk.call }
      if block_given?
        previous = @around_each
        @around_each = ->(&blk) { previous.call { block.call(&blk) } }
      end
      @around_each
    end
  end

  module FactoryBotRunnerExt
    def run(...)
      ::FactoryBot.around_each.call { super }
    end
  end

  ::FactoryBot.extend(FactoryBotExt)
  ::FactoryBot::FactoryRunner.prepend(FactoryBotRunnerExt)
end
