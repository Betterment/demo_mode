module FactoryBot
  class DefinitionProxy
    def clever_sequence(name, &block)
      sequence = CleverSequence.new(name, &block)
      add_attribute(name) { sequence.with_class(@instance&.class).next }
    end

    alias sequence clever_sequence
  end
end
