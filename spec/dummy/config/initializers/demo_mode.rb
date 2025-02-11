# frozen_string_literal: true

DemoMode.configure do
  signinable_username_method :name
  current_user_method :current_dummy_user
  splash_base_controller_name 'ApplicationController'
end

if Rails.env.development?
  DemoMode.configure do
    sign_up_path { foo_path }
    sign_in_path { bar_path }
    display_credentials true

    persona :the_everyperson do
      features << ''

      callout true
      sign_in_as { DummyUser.create!(name: SecureRandom.uuid) }
    end
  end

  DemoMode.add_persona :the_sometimesperson do
    features << 'foobar'
    callout true
    icon :tophat
    sign_in_as { DummyUser.create!(name: SecureRandom.uuid) }

    variant :the_rarely_person do
      sign_in_as { DummyUser.create!(name: SecureRandom.uuid) }
    end
  end

  DemoMode.add_persona :the_manyperson do
    features << 'shared account'
    features << 'other feature'
    features << 'lots of features'

    icon :users
    callout true

    sign_in_as { DummyUser.create!(name: SecureRandom.uuid) }
  end

  DemoMode.add_persona :the_less_important_person do
    features << 'rare feature'
    sign_in_as { DummyUser.create!(name: SecureRandom.uuid) }
  end

  DemoMode.add_persona :the_other_person do
    features << 'feature 1'
    features << 'nice feature'
    features << 'really important feature'

    variant 'ron' do
      sign_in_as { DummyUser.create!(name: "ron#{SecureRandom.uuid}") }
    end

    variant 'jan' do
      sign_in_as { DummyUser.create!(name: "jan#{SecureRandom.uuid}") }
    end
  end

  DemoMode.add_persona :redirects_to_not_found do
    features << 'redirects to a 404'
    display_credentials false

    begin_demo do
      redirect_to '/not_found_oh_no'
    end

    sign_in_as { Widget.create! }
  end
end
