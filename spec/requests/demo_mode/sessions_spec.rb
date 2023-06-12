require 'spec_helper'

RSpec.describe DemoMode::SessionsController do
  let(:response_json) { response.parsed_body }
  let(:request_headers) { { 'CONTENT_TYPE' => 'application/json', 'Accept' => 'application/json' } }

  context 'when demo mode is enabled', :demo_mode_enabled do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      DemoMode.configure do
        personas_path 'config/system-test-personas'
      end
    end

    describe 'POST /sessions' do
      context 'with forgery protection enabled' do
        around do |example|
          original_forgery_protection = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true

          example.run

          ActionController::Base.allow_forgery_protection = original_forgery_protection
        end

        it 'creates a session and redirects to the session' do
          post '/ohno/sessions', params: {
            session: { persona_name: 'the_everyperson', variant: 'alternate bruce' },
          }

          last_session = DemoMode::Session.last
          expect(last_session.variant).to eq 'alternate bruce'

          expect(response).to redirect_to "/ohno/sessions/#{last_session.id}"

          expect(controller.session.to_hash['session_id']).not_to be_nil
        end
      end
    end

    describe 'POST /sessions.json' do
      context 'without a variant' do
        it 'creates a session and returns processing json' do
          post '/ohno/sessions', params: {
            session: { persona_name: 'the_everyperson' },
          }.to_json, headers: request_headers

          last_session = DemoMode::Session.last
          expect(last_session.variant).to eq 'default'
          expect(response_json['id']).to eq last_session.id
          expect(response_json['processing']).to be true
          expect(response_json['username']).to be_nil
          expect(response_json['password']).to be_nil
        end
      end

      context 'with a variant' do
        it 'creates a session and returns processing json saving the variant on the created session' do
          post '/ohno/sessions', params: {
            session: {
              persona_name: 'the_everyperson',
              variant: 'alternate bruce',
            },
          }.to_json, headers: request_headers

          last_session = DemoMode::Session.last
          expect(last_session.variant).to eq 'alternate bruce'
          expect(response_json['id']).to eq last_session.id
          expect(response_json['processing']).to be true
          expect(response_json['username']).to be_nil
          expect(response_json['password']).to be_nil
        end
      end
    end

    describe 'GET /sessions/new.json' do
      it 'returns a list of personas in json' do
        get '/ohno/sessions/new', params: {}, headers: request_headers
        expect(response_json).to eq([
          {
            "persona_name" => "the_everyperson",
            "title" => "The Everyperson",
            "features" => ['Can sing'],
            "variants" => [{ "name" => "default" }, { "name" => "alternate bruce" }],
          },
          {
            "persona_name" => "zendaya",
            "title" => "Zendaya",
            "features" => ['Can sing and dance and act'],
            "variants" => [{ "name" => "default" }, { "name" => "MJ" }],
          },
        ])
      end
    end

    describe 'GET /sessions/:id.json' do
      context 'when persona is NOT ready' do
        it 'returns processing json' do
          session = DemoMode::Session.create!(persona_name: DemoMode.personas.first.name)
          session.reload.update!(signinable: nil)

          get "/ohno/sessions/#{session.id}", params: {}, headers: request_headers

          expect(response_json['id']).to eq session.id
          expect(response_json['processing']).to be true
          expect(response_json['username']).to be_nil
          expect(response_json['password']).to be_nil
        end
      end

      context 'when persona is ready' do
        it 'returns completed json' do
          session = DemoMode::Session.create!(persona_name: DemoMode.personas.first.name)
          DemoMode::AccountGenerationJob.perform_now(session)

          get "/ohno/sessions/#{session.id}", params: {}, headers: request_headers

          expect(response_json['id']).to eq session.id
          expect(response_json['processing']).to be false
          expect(response_json['username']).not_to be_nil
          expect(response_json['password']).not_to be_nil
        end
      end
    end
  end

  context 'when demo mode is not enabled' do
    it 'raises a Not Found (404)' do
      expect {
        get '/ohno/sessions/new.json', params: {}, headers: request_headers
      }.to raise_error(ActionController::RoutingError, 'Not Found')

      session = DemoMode::Session.create!(persona_name: DemoMode.personas.first.name)
      session.reload.update!(signinable: nil)
      expect {
        get "/ohno/sessions/#{session.id}", params: {}, headers: request_headers
      }.to raise_error(ActionController::RoutingError, 'Not Found')

      expect {
        post '/ohno/sessions', params: {
          session: { persona_name: 'the_everyperson' },
        }.to_json, headers: request_headers
      }.to raise_error(ActionController::RoutingError, 'Not Found')
    end
  end
end
