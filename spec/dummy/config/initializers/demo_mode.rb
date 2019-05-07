DemoMode.configure do
  signinable_username_method :name
  current_user_method :current_dummy_user
  splash_base_controller_name 'ApplicationController'
end
