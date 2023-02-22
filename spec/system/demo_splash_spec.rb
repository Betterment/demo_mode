require 'spec_helper'

describe 'Demo Splash' do
  context 'when demo mode is enabled', :demo_mode_enabled do
    before do
      DemoMode.configure do
        display_credentials false
        sign_up_path { nil }
        sign_in_path { nil }
        personas_path 'config/system-test-personas'
      end
    end

    it 'redirects to the splash, allows selecting a persona, and generates the account' do
      visit '/'
      expect(page).not_to have_text('Sign Up')
      expect(page).to have_text('Demo Mode')
      expect(page).to have_text('The Everyperson')
      expect(page).not_to have_text('Enter manually')

      within '.dm-Persona--theEveryperson' do
        click_on 'Sign In'
      end

      expect(page).to have_text('Your Name: Spruce Bringsteen')

      # it redirects back to splash after logging out:
      click_on 'Log out'
      expect(page).to have_current_path('/ohno/sessions/new')
    end

    context 'when selecting a variant on a callout persona' do
      it 'redirects to the splash, allows selecting a persona, and generates the account' do
        visit '/'
        expect(page).not_to have_text('Sign Up')
        expect(page).to have_text('Demo Mode')
        expect(page).to have_text('Zendaya')
        expect(page).not_to have_text('Enter manually')

        within '.dm-Persona--zendaya' do
          select('MJ', from: 'session_variant')
          click_on 'Sign In'
        end

        expect(page).to have_text('Your Name: MJ')

        # it redirects back to splash after logging out:
        click_on 'Log out'
        expect(page).to have_current_path('/ohno/sessions/new')
      end
    end

    context 'when display_credentials is true' do
      before do
        DemoMode.configure do
          display_credentials true
          password { 'aTESTpassword!123' }
        end
      end

      it 'redirects to the splash, allows selecting a persona, generates the account, and redirects to display credentials' do
        visit '/'
        expect(page).to have_text('Demo Mode')
        expect(page).to have_text('The Everyperson')

        within '.dm-Persona--theEveryperson' do
          click_on 'Sign In'
        end

        expect(find_field('Username').value).to eq('Spruce Bringsteen')
        expect(find_field('Password').value).to eq('aTESTpassword!123')
        click_on 'Sign in'
        expect(page).to have_text('Your Name: Spruce Bringsteen')
      end

      it 'redirects to the splash, allows selecting a non default variant, and generates the account' do
        visit '/'
        expect(page).to have_text('Demo Mode')
        expect(page).to have_text('The Everyperson')

        within '.dm-Persona--theEveryperson' do
          select('alternate bruce', from: 'session_variant')
          click_on 'Sign In'
        end

        expect(find_field('Username').value).to eq('Spruce Sringbeen')
        expect(find_field('Password').value).to eq('aTESTpassword!123')
      end

      context 'when a sign_in_path is specified' do
        before do
          DemoMode.configure do
            sign_in_path { bar_path }
          end
        end

        it 'shows a link to the expected path' do
          # redirects /signin to splash:
          visit '/signin'
          expect(page).to have_current_path('/ohno/sessions/new')

          expect(page).to have_text('Demo Mode')
          expect(page).to have_text('The Everyperson')

          within '.dm-Persona--theEveryperson' do
            click_on 'Sign In'
          end

          expect(find_field('Username').value).to eq('Spruce Bringsteen')
          expect(find_field('Password').value).to eq('aTESTpassword!123')

          new_window = window_opened_by { click_on 'Enter manually' }
          within_window new_window do
            expect(page).to have_text('Not a real sign in page')

            # does not redirect /signin to splash:
            visit '/signin'
            expect(page).to have_current_path('/signin')

            # does not redirect /to splash:
            visit '/'
            expect(page).to have_current_path('/')

            # after the custom demo session expires, it redirects again:
            travel 31.minutes do
              visit '/signin'
              expect(page).to have_current_path('/ohno/sessions/new')
            end
          end
        end
      end
    end

    context 'when a sign_up_path is specified' do
      before do
        DemoMode.configure do
          sign_up_path { foo_path }
        end
      end

      it 'shows a link to the expected path' do
        visit '/'
        expect(page).to have_text('Sign Up')
        click_on 'Sign Up'
        expect(page).to have_text('Not a real sign up page!')
      end
    end

    context 'with a second persona' do
      before do
        DemoMode.add_persona 'A Second Persona' do
          features << 'Cool feature'

          sign_in_as do |_pwd|
            DummyUser.create!(name: 'A Second Persona')
          end
        end
      end

      it 'allows filtering personas' do
        visit '/'

        fill_in 'Search...', with: 'A Second Persona'
        expect(page).to have_text('A Second Persona')
        before = page.text
        sleep 1
        after = page.text
        if before != after
          puts "Before: #{before.inspect}\nAfter: #{after.inspect}"
          exit 2
        end

        expect(page).not_to have_text('The Everyperson')

        fill_in 'Search...', with: 'The Everyperson', wait: 1
        expect(page).to have_text('The Everyperson')
        expect(page).not_to have_text('A Second Persona')

        page.go_back
        expect(page).to have_text('A Second Persona')
        expect(page).not_to have_text('The Everyperson')

        page.go_forward
        expect(page).to have_text('The Everyperson')
        expect(page).not_to have_text('A Second Persona')

        within '.dm-Persona--theEveryperson' do
          click_on 'Sign In'
        end

        expect(page).to have_text('Your Name: Spruce Bringsteen')
      end
    end

    context 'when a persona uses a custom sign in method' do
      before do
        DemoMode.add_persona :redirects_to_not_found do
          features << 'redirects to a 404'

          begin_demo do
            redirect_to '/not_found_oh_no'
          end

          sign_in_as { Widget.create! }
        end
      end

      it 'runs the custom block in the controller context' do
        visit '/'
        expect(page).not_to have_text('Sign Up')
        expect(page).to have_text('Demo Mode')
        expect(page).to have_text('Redirects To Not Found')

        within '.dm-Persona--redirectsToNotFound' do
          click_on 'Sign In'
        end

        expect(page).to have_current_path('/not_found_oh_no')
        expect(DemoMode::Session.last.signinable).to be_a(Widget)
      end
    end
  end

  context 'when demo mode is not enabled' do
    it 'shows the unauthenticated root path' do
      visit '/'
      expect(page).to have_text('Not signed in!')
    end
  end
end
