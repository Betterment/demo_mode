# frozen_string_literal: true

ENV["RAILS_ENV"] ||= 'test'
require_relative 'dummy/config/environment'

require 'factory_bot'
require 'demo_mode/factory_bot_ext'
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

  config.around(:each, :with_queue_adapter) do |example|
    queue_adapter_was = ActiveJob::Base.queue_adapter
    new_adapter = example.metadata[:with_queue_adapter]

    ActiveJob::Base.queue_adapter = new_adapter
    example.run
  ensure
    ActiveJob::Base.queue_adapter = queue_adapter_was
  end

  config.around(:each, :demo_mode_enabled) do |example|
    ENV['DEMO_MODE'] = '1'
    example.run
  ensure
    ENV.delete('DEMO_MODE')
  end
end

RSpec::Matchers.define :emit_notification do |expected_event_name|
  attr_reader :actual, :expected

  def supports_block_expectations?
    true
  end

  chain :with_payload, :expected_payload
  chain :with_value, :expected_value
  diffable

  match do |block|
    @expected = { event_name: expected_event_name, payload: expected_payload, value: expected_value }
    @actuals = []
    callback = ->(name, _started, _finished, _unique_id, payload) do
      @actuals << { event_name: name, payload: payload.except(:value), value: payload[:value] }
    end

    ActiveSupport::Notifications.subscribed(callback, expected_event_name, &block)

    unless expected_payload
      @actuals.each { |a| a.delete(:payload) }
      @expected.delete(:payload)
    end

    @actual = @actuals.select { |a| values_match?(@expected.except(:value), a.except(:value)) }
    @expected = [@expected]
    values_match?(@expected, @actual)
  end

  failure_message do
    <<~MSG
      Expected the code block to emit:
        #{@expected.first.inspect}

      But instead, the following were emitted:
        #{(@actual.presence || @actuals).map(&:inspect).join("\n  ")}
    MSG
  end
end

RSpec::Matchers.define_negated_matcher(:not_emit_notification, :emit_notification)
