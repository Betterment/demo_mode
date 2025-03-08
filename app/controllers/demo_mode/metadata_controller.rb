# frozen_string_literal: true

module DemoMode
  class MetadataController < DemoMode::ApplicationController
    # Support link based session creation
    skip_forgery_protection only: :create

    def create
      @session = Session.new(create_params)
      @session.save_and_generate_account!(**options_params.to_unsafe_h.deep_symbolize_keys)
      session[:demo_session] = { 'id' => @session.id, 'last_request_at' => Time.zone.now }

      respond_to do |f|
        f.json { render_signinable_json }
      end
    end

    private

    def render_signinable_json
      render json: {
        id: @session.id,
        status: @session.status,
        metadata: @session.signinable_metadata,
      }
    end

    def create_params
      params.permit(:persona_name, :variant)
    end

    def options_params
      params.fetch(:options, {}).permit!
    end
  end
end
