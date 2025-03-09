# frozen_string_literal: true

module DemoMode
  class SessionsController < DemoMode::ApplicationController
    skip_before_action :demo_splash!, raise: false

    # Support link based session creation
    skip_forgery_protection only: :create

    def show
      @session = Session.find(params[:id])
      respond_to do |f|
        f.html { begin_demo_if_ready! }
        f.json { render_signinable_json }
      end
    end

    def new
      @session = Session.new
      respond_to do |f|
        f.html { render :new }
        f.json { render_personas_json }
      end
    end

    def create
      @session = Session.new(create_params)
      @session.save_and_generate_account_later!(**options_params.to_unsafe_h.deep_symbolize_keys)
      session[:demo_session] = { 'id' => @session.id, 'last_request_at' => Time.zone.now }
      respond_to do |f|
        f.html { redirect_to @session, status: :see_other }
        f.json { render_signinable_json }
      end
    end

    def update
      @session = Session.find(params[:id])
      begin_demo!
    end

    private

    def begin_demo_if_ready!
      begin_demo! if @session.signinable && !@session.display_credentials?
    end

    def begin_demo!
      instance_eval(&@session.begin_demo.call(**query_params.to_unsafe_h.deep_symbolize_keys))
    end

    def render_signinable_json
      if @session.signinable.blank?
        render json: { id: @session.id, processing: true }
      else
        render json: {
          id: @session.id,
          processing: false,
          username: @session.signinable_username,
          password: @session.signinable_password,
        }
      end
    end

    def render_personas_json
      render(
        json: DemoMode.personas.map do |persona|
          {
            persona_name: persona.name,
            title: persona.name.to_s.titleize,
            features: persona.features,
            variants: persona.variants.map { |name, _| { name: name } },
          }
        end,
      )
    end

    def create_params
      params.require(:session).permit(:persona_name, :variant)
    end

    def options_params
      params.fetch(:options, {}).permit!
    end

    def query_params
      params.permit(:redirect_to)
    end
  end
end
