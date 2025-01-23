# frozen_string_literal: true

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
  config.active_support.to_time_preserves_timezone = :zone

  config.action_dispatch.show_exceptions = if ActiveSupport.version >= Gem::Version.new('7.1')
                                             :none
                                           else
                                             false
                                           end
end

require 'rspec/rails'
require 'capybara/cuprite'

Capybara.register_driver(:better_cuprite) do |app|
  browser_options = ENV.fetch('CI', nil) ? { 'no-sandbox': nil } : {}

  options = {
    window_size: [1280, 1024],
    headless: ENV['CAPYBARA_DEBUG'] != '1',
    process_timeout: 20,
    js_errors: true,
    browser_options: browser_options,
  }

  Capybara::Cuprite::Driver.new(app, **options)
end

Capybara.configure do |config|
  config.match = :one
  config.ignore_hidden_elements = true
  config.visible_text_only = true
  config.default_driver = :better_cuprite
  config.javascript_driver = :better_cuprite

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
    driven_by :better_cuprite
  end

  # Reset configuration
  config.before(:each) do
    DemoMode.send(:remove_instance_variable, '@configuration')
    load Rails.root.join('config/initializers/demo_mode.rb')
  end

  config.around(:each, :demo_mode_enabled) do |example|
    ENV['DEMO_MODE'] = '1'
    example.run
  ensure
    ENV.delete('DEMO_MODE')
  end
end
