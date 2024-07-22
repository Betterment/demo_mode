# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::Session do
  it 'validates persona name' do
    subject.persona_name = nil
    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to match_array("Persona name can't be blank")
  end

  it 'validates persona exists on create' do
    subject.persona_name = 'garbage'
    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to match_array("Persona must exist")
  end

  it 'allows persisted records to reference non-existent personas' do
    subject.persona_name = :the_everyperson
    subject.variant = 'XIV'

    expect(subject).not_to be_valid
    expect(subject.errors.full_messages).to match_array("Persona must exist")

    subject.save!(validate: false) # bypass validations on create
    expect(subject).to be_valid
  end

  it 'validates persona variant' do
    subject.variant = nil
    expect(subject).not_to be_valid
    expect(subject.errors[:variant]).to match_array("can't be blank")
  end

  describe '#persona' do
    before do
      DemoMode.configure do
        personas_path 'config/system-test-personas'
      end
    end

    it 'finds the persona by name' do
      session = described_class.new(persona_name: :the_everyperson)
      expect(session.persona).to be_a(DemoMode::Persona)
    end

    it 'does not find the persona when the persona must exist' do
      session = described_class.new(persona_name: :garbage)
      expect(session.persona).to be_nil
    end
  end

  describe '#begin_demo' do
    it 'returns nil' do
      expect(subject.begin_demo).to be_nil
    end

    context 'when the persona provides a custom sign in behavior' do
      before do
        DemoMode.add_persona :hal_9000 do
          features << ""
          sign_in_as { DummyUser.create!(name: 'HAL') }

          begin_demo do
            raise "I'm afraid I can't do that, Dave."
          end
        end
      end

      it 'returns a proc that raises the expected message' do
        subject.persona_name = :hal_9000
        expect(subject.begin_demo).to be_present
        expect { subject.begin_demo.call }
          .to raise_error "I'm afraid I can't do that, Dave."
      end
    end
  end
end
