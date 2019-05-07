DemoMode.add_persona do
  # See README at https://github.com/Betterment/demo_mode

  sign_in_as do
    # Construct your user here. For example:
    # FactoryBot.create(:user)
  end

  # Features that make this persona unique:
  features << 'a sample persona! find me at:'
  features << 'config/personas/sample_persona.rb'

  # "Callout" personas render at the top, above the table:
  callout true

  # Use the `icon` config to change the persona's icon.
  #
  # Built-in icons include `:user` (default), `:users`, and `:tophat`:
  # ==========
  # icon :user
  #
  # Specify a string to use an asset in the asset pipeline:
  # =======================================================
  # icon 'path/to/my/icon.png'
  #
  # Specify a block to render your own icon:
  # ========================================
  # icon do
  #   # Any view helpers are available in this context.
  #   image_tag('images/dancing-penguin.gif')
  # end

  # Define "variants" with the `variant` keyword:
  # =============================================
  # variant 'pending invite' do
  #   sign_in_as do
  #     FactoryBot.create(:user, :pending_invite)
  #   end
  # end

  # Display the login credentials before signing in:
  # ================================================
  # display_credentials

  # To do something other than "sign in"
  # (e.g. redirect to an exclusive sign up link)
  # ============================================
  # begin_demo do
  #   redirect_to sign_up_path(invite: @session.signinable.invite_token)
  # end
end
