module DemoMode
  class ApplicationController < DemoMode.splash_base_controller_name.constantize
    protect_from_forgery with: :null_session

    before_action unless: -> { DemoMode.enabled? } do
      raise ActionController::RoutingError, 'Not Found'
    end

    layout 'demo_mode/application'
  end
end
