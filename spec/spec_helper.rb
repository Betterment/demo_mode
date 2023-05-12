ENV["RAILS_ENV"] ||= 'test'

require 'bundler'
Bundler.require :default, :development

require 'uncruft'
require 'demo_mode/factory_bot_ext'
require 'webrick'

Combustion.path = 'spec/dummy'
Combustion.initialize! :all do
  config.assets.precompile << 'path/to/test-icon.png'

  config.autoloader = :zeitwerk
  config.active_job.queue_adapter = :inline
end

require 'rspec/rails'

capybara_driver = ENV.fetch("CAPYBARA_DRIVER", 'selenium_chrome_headless').to_sym

case capybara_driver
  when :selenium_chrome_headless
    Capybara.register_driver :selenium_chrome_headless do |app|
      args = %w(headless disable-gpu disable-dev-shm-usage no-sandbox window-size=1280,1024)
      Capybara::Selenium::Driver.new app,
                                     browser: :chrome,
                                     capabilities: [Selenium::WebDriver::Chrome::Options.new(args: args)]
    end
  when :selenium_remote_chrome
    url = ENV.fetch("SELENIUM_REMOTE_URL", "http://localhost:4444/wd/hub")

    Capybara.register_driver :selenium_remote_chrome do |app|
      Capybara::Selenium::Driver.new(app, browser: :remote, desired_capabilities: :chrome, url: url).tap do |driver|
        driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(1280, 1024)
        driver.browser.file_detector = ->(args) {
          str = args.first.to_s
          str if File.exist?(str)
        }
      end
    end
  else
    Capybara.register_driver capybara_driver do |app|
      Capybara::Selenium::Driver.new(app, browser: capybara_driver)
    end
end

Capybara.configure do |config|
  config.match = :one
  config.ignore_hidden_elements = true
  config.visible_text_only = true
  config.default_driver = capybara_driver
  config.javascript_driver = capybara_driver

  config.default_max_wait_time = ENV.fetch('CAPYBARA_WAIT_TIME', 2).to_i
  config.server = :webrick
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.run_all_when_everything_filtered = true
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.include Capybara::DSL
  config.include ActiveSupport::Testing::TimeHelpers
  config.infer_spec_type_from_file_location!

  config.before(:each, type: :system) do
    driven_by capybara_driver
  end

  config.around(:each, :demo_mode_enabled) do |example|
    ENV['DEMO_MODE'] = '1'
    example.run
  ensure
    ENV.delete('DEMO_MODE')
  end
end
