# frozen_string_literal: true

module DemoMode
  class Engine < ::Rails::Engine
    isolate_namespace DemoMode
    engine_name 'demo_mode'

    unless Rails.env.production?
      rake_tasks do
        load 'demo_mode/tasks.rb'
      end

      initializer 'demo_mode' do |app|
        require 'zeitwerk/version'
        raise 'DemoMode only supports Zeitwerk::VERSION >= 2.4.2' unless Gem::Version.new(Zeitwerk::VERSION) >= Gem::Version.new('2.4.2')

        Rails.autoloaders.main.on_load(DemoMode.app_base_controller_name) do
          DemoMode.app_base_controller_name.constantize.include Demoable
        end

        app.middleware.insert_before(ActionDispatch::Static, ActionDispatch::Static, "#{root}/public")
      end
    end
  end
end
