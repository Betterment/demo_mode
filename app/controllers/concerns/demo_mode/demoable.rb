# frozen_string_literal: true

module DemoMode
  module Demoable
    extend ActiveSupport::Concern

    included do
      before_action :_demo_mode_logout_check!, if: -> { DemoMode.enabled? && current_demo_session }
      before_action :demo_splash!, if: -> { DemoMode.enabled? }
    end

    def current_demo_session
      if session.key?(:demo_session)
        @current_demo_session = nil if @current_demo_session&.id != session[:demo_session]['id']
        @current_demo_session ||= Session.find(session[:demo_session]['id'])
      end
    end

    private

    def _demo_mode_logout_check!
      if _demo_mode_timed_out? || _demo_mode_logged_out?
        session.delete(:demo_session)
      else
        session[:demo_session]['signinable_id'] = _demo_mode_current_signinable&.id
        session[:demo_session]['last_request_at'] = Time.zone.now
      end
    end

    def demo_splash!
      if _demo_mode_current_signinable.blank? && !current_demo_session&.custom_sign_in?
        sign_out
        redirect_to demo_mode.new_session_path
      end
    end

    def _demo_mode_timed_out?
      session[:demo_session]['last_request_at'] <= DemoMode.session_timeout.ago
    end

    def _demo_mode_logged_out?
      session[:demo_session]['signinable_id'] && !_demo_mode_current_signinable
    end

    def _demo_mode_current_signinable
      send(DemoMode.current_user_method)
    end
  end
end
