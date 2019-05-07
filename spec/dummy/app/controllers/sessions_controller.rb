class SessionsController < ApplicationController
  def show
    if current_dummy_user
      render inline: <<~BODY # rubocop:disable Rails/RenderInline
        Your Name: #{current_dummy_user.name}<br/>
        <a href='/signout'>Log out</a>
      BODY
    else
      render plain: 'Not signed in!'
    end
  end

  def new
    render plain: 'Not a real sign in page'
  end

  def destroy
    session.delete(:dummy_user_id)
    redirect_to root_path
  end
end
