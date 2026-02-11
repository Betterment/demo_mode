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

  describe 'structured logging' do
    let(:logged_json) { [] }

    before do
      logged_json.clear
      allow(Rails.logger).to receive(:info) { |json| logged_json << json }
      allow(Rails.logger).to receive(:error) { |json| logged_json << json }
    end

    def find_log_event(event_name)
      logged_json.filter_map { |json| JSON.parse(json) rescue nil }
                 .find { |e| e['event'] == event_name }
    end

    it 'logs started event with required fields' do
      described_class.perform_now(session)

      started_log = find_log_event('demo_mode.account_generation.started')

      expect(started_log).to include(
        'session_id' => session.id,
        'persona_name' => 'the_everyperson',
        'variant' => 'default'
      )
      expect(started_log['start_time']).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it 'logs completed event with timing and signinable data' do
      described_class.perform_now(session)
      session.reload

      completed_log = find_log_event('demo_mode.account_generation.completed')

      expect(completed_log).to include(
        'session_id' => session.id,
        'persona_name' => 'the_everyperson',
        'variant' => 'default',
        'signinable_id' => session.signinable_id,
        'signinable_type' => session.signinable_type
      )
      expect(completed_log['duration_ms']).to be_a(Numeric)
      expect(completed_log['start_time']).to be_present
      expect(completed_log['end_time']).to be_present
      expect(completed_log['sequences_used']).to be_an(Array)
      expect(completed_log['sequences_used_count']).to be_an(Integer)
    end

    it 'includes sequence tracking data with correct structure' do
      described_class.perform_now(session)

      completed_log = find_log_event('demo_mode.account_generation.completed')
      sequences = completed_log['sequences_used']

      sequences.each do |seq|
        expect(seq).to have_key('class')
        expect(seq).to have_key('attribute')
        expect(seq).to have_key('value')
      end
    end

    context 'when generation fails' do
      let(:session) do
        DemoMode::Session.create!(persona_name: :the_everyperson, variant: :erroring)
      end

      it 'logs failed event with error details' do
        expect {
          described_class.perform_now(session)
        }.to raise_error(RuntimeError)

        failed_log = find_log_event('demo_mode.account_generation.failed')

        expect(failed_log).to include(
          'session_id' => session.id,
          'persona_name' => 'the_everyperson',
          'error_class' => 'RuntimeError',
          'error_message' => 'Oops! Error error!'
        )
        expect(failed_log['duration_ms']).to be_a(Numeric)
      end
    end

    context 'when persona does not exist' do
      let(:session) do
        session = DemoMode::Session.new(persona_name: :nonexistent)
        session.save!(validate: false)
        session
      end

      it 'logs failed event with unknown persona error' do
        expect {
          described_class.perform_now(session)
        }.to raise_error(RuntimeError, 'Unknown persona: nonexistent')

        failed_log = find_log_event('demo_mode.account_generation.failed')

        expect(failed_log).to include(
          'error_class' => 'RuntimeError',
          'error_message' => 'Unknown persona: nonexistent'
        )
      end
    end
  end
end
