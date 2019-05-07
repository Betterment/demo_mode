class ApplicationController < ActionController::Base
  private

  def sign_in(dummy_user)
    session[:dummy_user_id] = dummy_user.id
  end

  def sign_out
    session.delete(:dummy_user_id)
  end

  def current_dummy_user
    @current_dummy_user ||= DummyUser.find_by(id: session[:dummy_user_id])
  end
end
