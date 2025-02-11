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
  end

  context 'when the persona must exist' do
    let(:session) do
      session = DemoMode::Session.new(persona_name: :garbage)
      session.save!(validate: false)
      session
    end

    it 'raises an exception' do
      expect {
        described_class.perform_now(session)
      }.to raise_error(RuntimeError, 'Unknown persona: garbage')
    end
  end

  context 'when there is an error generating the persona' do
    let(:session) do
      DemoMode::Session.create!(persona_name: :the_everyperson, variant: :erroring)
    end

    it 'saves the failed_at timestamp to the session' do
      expect {
        described_class.perform_now(session)
      }.to raise_error(RuntimeError, 'Failed to create signinable persona!')
        .and change { session.reload.failed_at }.from(nil).to(be_present)
    end
  end
end
