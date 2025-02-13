# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::AccountGenerationJob do
  before do
    allow(Rails.logger).to receive(:error).and_call_original
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
      .and change { session.reload.status }.from('processing').to('successful')
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
    end
  end
end
