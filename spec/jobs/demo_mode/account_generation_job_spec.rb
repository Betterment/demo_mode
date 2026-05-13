# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::AccountGenerationJob do
  before do
    DemoMode.configure do
      personas_path 'config/system-test-personas'
    end
  end

  let(:session) do
    DemoMode::Session.create!(persona_name: :the_everyperson)
  end

  it 'generates a new account and assigns it to the session' do
    expect {
      described_class.perform_now(session)
    }.to change { session.reload.signinable }.from(nil).to(kind_of(DummyUser))
      .and change { session.reload.status }.from('processing').to('in_use')
      .and emit_notification('demo_mode.persona.generate').with_payload(
        name: 'the_everyperson',
        variant: 'default',
      )
  end

  context 'when the persona has an at_claim callback' do
    before do
      DemoMode.add_persona('at_claim_persona') do
        features << 'test'
        at_claim { |u| u.update!(name: 'claimed') }
        sign_in_as { DummyUser.create!(name: 'original') }
      end
    end

    context 'when the session was claimed (pool miss)' do
      let(:session) { DemoMode::Session.create!(persona_name: 'at_claim_persona') }

      it 'invokes the callback after account generation' do
        described_class.perform_now(session)
        expect(session.reload.signinable.name).to eq('claimed')
      end
    end

    context 'when the session is a pool pre-generation' do
      let(:session) { DemoMode::Session.create!(persona_name: 'at_claim_persona', pool_session: true) }

      it 'does not invoke the callback' do
        described_class.perform_now(session)
        expect(session.reload.signinable.name).to eq('original')
      end
    end

    context 'when the at_claim callback raises' do
      before do
        DemoMode.add_persona('erroring_at_claim_persona') do
          features << 'test'
          at_claim { |_| raise 'oops!' }
          sign_in_as { DummyUser.create!(name: 'original') }
        end
      end

      let(:session) { DemoMode::Session.create!(persona_name: 'erroring_at_claim_persona') }

      it 'marks the session as failed and re-raises the error' do
        expect {
          described_class.perform_now(session)
        }.to raise_error(RuntimeError, 'oops!')
          .and change { session.reload.status }.to('failed')
      end
    end

    context 'when the at_claim callback raises a uniqueness violation' do
      before do
        DemoMode.add_persona('uniqueness_violating_at_claim_persona') do
          features << 'test'
          at_claim { |u| DummyUser.create!(id: u.id, name: 'duplicate') }
          sign_in_as { DummyUser.create!(name: 'original') }
        end
      end

      # Exercise the joinable outer transaction in save_and_generate_account! so the
      # PG-aborted state would propagate without the savepoint inside #perform.
      it 'propagates the original RecordNotUnique through the joinable outer transaction' do
        session = DemoMode::Session.new(persona_name: 'uniqueness_violating_at_claim_persona')
        expect {
          session.save_and_generate_account!
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  it 'stores the persona checksum on the session' do
    described_class.perform_now(session)
    expect(session.reload.persona_checksum).to eq(session.persona.file_checksum)
  end

  context 'when the persona must exist' do
    let(:session) do
      session = DemoMode::Session.new(persona_name: :garbage)
      session.save!(validate: false)
      session
    end

    it 'logs an error and sets the status to failed' do
      expect {
        described_class.perform_now(session)
      }.to raise_error(RuntimeError, 'Unknown persona: garbage')
        .and change { session.reload.status }.from('processing').to('failed')
        .and not_emit_notification('demo_mode.persona.generate')
    end
  end

  context 'when there is an error generating the persona' do
    let(:session) do
      DemoMode::Session.create!(persona_name: :the_everyperson, variant: :erroring)
    end

    it 'logs an error and sets the status to failed' do
      expect {
        described_class.perform_now(session)
      }.to raise_error(RuntimeError, 'Oops! Error error!')
        .and change { session.reload.status }.from('processing').to('failed')
        .and emit_notification('demo_mode.persona.generate').with_payload(
          name: 'the_everyperson',
          variant: 'erroring',
          exception: ["RuntimeError", "Oops! Error error!"],
          exception_object: kind_of(RuntimeError),
        )
    end
  end
end
