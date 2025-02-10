require 'bundler/setup'
require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_job/railtie'
require 'active_model/railtie'
require 'active_record/railtie'
require 'sprockets/railtie'

Bundler.require(:default, Rails.env)

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = Rails.env.test?
    config.cache_classes = Rails.env.test?
    config.consider_all_requests_local = true
    config.action_dispatch.show_exceptions = false
    config.action_controller.allow_forgery_protection = Rails.env.development?
    config.active_support.deprecation = :raise
    config.active_job.queue_adapter = :inline
    config.assets.precompile << 'path/to/test-icon.png'
  end
end
