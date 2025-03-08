# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::MetadataController do # rubocop:disable RSpec/FilePath
  let(:response_json) { response.parsed_body }
  let(:request_headers) { { 'CONTENT_TYPE' => 'application/json', 'Accept' => 'application/json' } }

  before do
    DemoMode.configure do
      personas_path 'config/system-test-personas'
    end
  end

  context 'when demo mode is enabled', :demo_mode_enabled do
    describe 'POST /metadata.json' do
      context 'with metadata' do
        before do
          DemoMode.configure do
            metadata %w(name)
          end
        end

        it 'creates a session and returns the metadata' do
          post '/ohno/metadata.json', params: {
            session: {
              persona_name: 'the_everyperson',
            },
          }.to_json, headers: request_headers

          last_session = DemoMode::Session.last
          expect(response_json['id']).to eq last_session.id
          expect(response_json['status']).to eq 'successful'
          expect(response_json['metadata']).to eq({ name: 'fewfe' })
        end
      end

      context 'with no metadata' do
        it 'creates a session and returns no metadata' do
          post '/ohno/metadata.json', params: {
            session: {
              persona_name: 'the_everyperson',
            },
          }.to_json, headers: request_headers
          puts '********************'
          puts response_json
          puts '********************'
          last_session = DemoMode::Session.last
          expect(response_json['id']).to eq last_session.id
          expect(response_json['status']).to eq 'successful'
          expect(response_json['metadata']).to be_nil
        end
      end
    end
  end
end
