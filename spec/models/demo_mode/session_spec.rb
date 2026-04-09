# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::Session do
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
      session.persona_checksum = session.persona&.file_checksum
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

    it 'excludes sessions with a stale checksum' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      session.status = 'available'
      session.persona_checksum = 'stale_checksum'
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).not_to include(session)
    end

    it 'excludes sessions with no checksum' do
      session = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      session.status = 'available'
      session.save!(validate: false)

      expect(described_class.available_for(:the_everyperson, 'default')).not_to include(session)
    end
  end

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

  it 'validates claimed_at must be absent when available' do
    subject.claimed_at = Time.zone.now
    subject.status = 'available'
    expect(subject).not_to be_valid
    expect(subject.errors[:claimed_at]).to be_present
  end

  it 'validates claimed_at must be present when in_use' do
    subject.status = 'in_use'
    expect(subject).not_to be_valid
    expect(subject.errors[:claimed_at]).to be_present
  end

  it 'validates available status requires signinable' do
    subject.status = 'available'
    expect(subject).not_to be_valid
    expect(subject.errors[:status]).to include('cannot be available or in_use if signinable is not present')
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

  describe '#signinable_metadata' do
    before do
      DemoMode.configure do
        personas_path 'config/system-test-personas'
      end
    end

    it 'returns empty hash when processing' do
      subject.persona_name = :the_everyperson
      expect(subject.signinable_metadata).to eq({})
    end

    it 'returns empty hash when failed' do
      subject.persona_name = :the_everyperson
      subject.status = 'failed'
      expect(subject.signinable_metadata).to eq({})
    end

    it 'returns metadata when available' do
      session = described_class.new(persona_name: :the_everyperson)
      session.signinable = DummyUser.create!(name: 'test')
      session.status = 'available'
      session.save!(validate: false)
      expect(session.signinable_metadata).to eq({})
    end

    it 'returns metadata when in_use' do
      session = described_class.new(persona_name: :the_everyperson)
      session.signinable = DummyUser.create!(name: 'test')
      session.status = 'in_use'
      session.claimed_at = Time.zone.now
      session.save!(validate: false)
      expect(session.signinable_metadata).to eq({})
    end
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

  describe '.claim_for' do
    before do
      DemoMode.configure do
        personas_path 'config/system-test-personas'
      end
    end

    it 'claims and returns an existing available pool session' do
      pooled = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      pooled.signinable = DummyUser.create!(name: 'test')
      pooled.status = 'available'
      pooled.persona_checksum = pooled.persona&.file_checksum
      pooled.save!(validate: false)

      result = described_class.claim_for(persona_name: :the_everyperson, variant: 'default')

      expect(result.id).to eq(pooled.id)
      expect(result.status).to eq('in_use')
      expect(result.claimed_at).to be_present
    end

    it 'creates a new session when no pool session is available' do
      result = described_class.claim_for(persona_name: :the_everyperson, variant: 'default')

      expect(result).to be_persisted
      expect(result.status).to eq('processing')
      expect(result.claimed_at).to be_present
    end

    it 'enqueues an account generation job for a new session', with_queue_adapter: :test do
      expect {
        described_class.claim_for(persona_name: :the_everyperson, variant: 'default')
      }.to have_enqueued_job(DemoMode::AccountGenerationJob)
    end

    it 'does not enqueue an account generation job when claiming a pool session', with_queue_adapter: :test do
      pooled = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      pooled.signinable = DummyUser.create!(name: 'test')
      pooled.status = 'available'
      pooled.persona_checksum = pooled.persona&.file_checksum
      pooled.save!(validate: false)

      expect {
        described_class.claim_for(persona_name: :the_everyperson, variant: 'default')
      }.not_to have_enqueued_job(DemoMode::AccountGenerationJob)
    end

    it 'passes generation options through to the account generation job', with_queue_adapter: :test do
      expect {
        described_class.claim_for(persona_name: :the_everyperson, variant: 'default', custom_option: 'value')
      }.to have_enqueued_job(DemoMode::AccountGenerationJob).with(anything, custom_option: 'value')
    end

    it 'uses the default variant when none is specified' do
      result = described_class.claim_for(persona_name: :the_everyperson)

      expect(result.variant).to eq('default')
    end

    it 'emits demo_mode.session.claimed with pool_hit: true when claiming a pool session' do
      pooled = described_class.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
      pooled.signinable = DummyUser.create!(name: 'test')
      pooled.status = 'available'
      pooled.save!(validate: false)

      expect {
        described_class.claim_for(persona_name: :the_everyperson, variant: 'default')
      }.to emit_notification('demo_mode.session.claimed')
        .with_payload(persona_name: :the_everyperson, variant: 'default', pool_hit: true)
    end

    it 'emits demo_mode.session.claimed with pool_hit: false when no pool session is available' do
      expect {
        described_class.claim_for(persona_name: :the_everyperson, variant: 'default')
      }.to emit_notification('demo_mode.session.claimed')
        .with_payload(persona_name: :the_everyperson, variant: 'default', pool_hit: false)
    end
  end

  describe '#claim!' do
    context 'with an existing available session' do
      let(:session) do
        s = described_class.new(persona_name: :the_everyperson, pool_session: true)
        s.signinable = DummyUser.create!(name: 'test')
        s.status = 'available'
        s.save!(validate: false)
        s
      end

      it 'transitions status to in_use' do
        expect { session.claim! }.to change { session.reload.status }.from('available').to('in_use')
      end

      it 'sets claimed_at' do
        expect { session.claim! }.to change { session.reload.claimed_at }.from(nil)
      end

      it 'raises when the session is already in_use' do
        session.claim!
        expect { session.claim! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with a new record' do
      before do
        DemoMode.configure do
          personas_path 'config/system-test-personas'
        end
      end

      let(:session) { described_class.new(persona_name: :the_everyperson) }

      it 'persists the record' do
        expect { session.claim! }.to change { session.persisted? }.from(false).to(true)
      end

      it 'sets claimed_at' do
        expect { session.claim! }.to change { session.claimed_at }.from(nil)
      end

      it 'leaves status as processing since there is no signinable yet' do
        session.claim!
        expect(session.status).to eq('processing')
      end
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
