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

  it 'validates available status requires signinable' do
    subject.status = 'available'
    expect(subject).not_to be_valid
    expect(subject.errors[:status]).to include('cannot be available or in_use if signinable is not present')
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

  describe 'pool behavior' do
    it 'sets claimed_at on create for non-pool sessions' do
      subject.persona_name = :the_everyperson
      subject.save!(validate: false)
      expect(subject.claimed_at).to be_present
    end

    it 'leaves claimed_at nil on create for pool sessions' do
      subject.persona_name = :the_everyperson
      subject.pool_session = true
      subject.save!(validate: false)
      expect(subject.claimed_at).to be_nil
    end
  end

  describe '.unclaimed' do
    it 'returns sessions with no claimed_at' do
      unclaimed = described_class.new(persona_name: :the_everyperson, pool_session: true)
      unclaimed.save!(validate: false)
      claimed = described_class.new(persona_name: :the_everyperson)
      claimed.save!(validate: false)

      expect(described_class.unclaimed).to include(unclaimed)
      expect(described_class.unclaimed).not_to include(claimed)
    end
  end

  describe '.claimed' do
    it 'returns sessions with a claimed_at value' do
      unclaimed = described_class.new(persona_name: :the_everyperson, pool_session: true)
      unclaimed.save!(validate: false)
      claimed = described_class.new(persona_name: :the_everyperson)
      claimed.save!(validate: false)

      expect(described_class.claimed).to include(claimed)
      expect(described_class.claimed).not_to include(unclaimed)
    end
  end

  describe '.available_for' do
    before do
      DemoMode.configure do
        personas_path 'config/system-test-personas'
      end
    end

    it 'returns available unclaimed sessions matching persona and variant' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      session.status = 'available'
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).to include(session)
    end

    it 'excludes processing sessions' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).not_to include(session)
    end

    it 'excludes claimed sessions' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'default')
      session.status = 'available'
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).not_to include(session)
    end

    it 'excludes sessions with a different persona or variant' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'other', pool_session: true)
      session.status = 'available'
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).not_to include(session)
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
