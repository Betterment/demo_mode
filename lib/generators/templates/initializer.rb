# See README at https://github.com/Betterment/demo_mode

DemoMode.configure do
  # The name of the 'current user' method in your application's controllers:
  # =================================
  # current_user_method :current_user

  # The base controller for the persona splash page:
  # ================================================
  # splash_base_controller_name 'ActionController::Base'

  # The base controller used by your application (for redirecting to the splash page):
  # ================================================
  # app_base_controller_name 'ApplicationController' # You may want something narrower, e.g. 'LoginsController'

  # The name of the "base" ActiveJob class inherited by the persona generation job:
  # ===============================
  # base_job_name 'ActiveJob::Base'

  # The sign up path for your app (displayed in the upper right of the splash page):
  # =================================
  # sign_up_path { app_sign_up_path }

  # To allow for manual sign ins with provided credentials, specify the following:
  # ===============================
  # display_credentials
  # sign_in_path { app_login_path }
  #
  # NOTE: You will want to persist `DemoMode.current_password` onto your personas!

  # The location of the personas folder:
  # ====================================
  # personas_path 'config/personas'

  # A callback that wraps persona-based account generation.
  # You must run `generator.call` and return the "signinable" object:
  # ==================================================
  # around_persona_generation do |generator|
  #   GlobalState.clear!
  #   generator.call.tap do |account|
  #     account.update!(metadata: '123')
  #   end
  # end

  # Personas can also be in-lined within the config itself,
  # if you prefer to keep them all in one file:
  # ===========================================
  # persona :basic_user do
  #   FactoryBot.create(:user)
  # end
  #
  # persona :pro_user do
  #   FactoryBot.create(:user, :pro)
  # end
end
