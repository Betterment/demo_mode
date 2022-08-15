require 'sprockets/railtie'

module DemoMode
  class Engine < ::Rails::Engine
    isolate_namespace DemoMode
    engine_name 'demo_mode'

    unless Rails.env.production?
      rake_tasks do
        load 'demo_mode/tasks.rb'
      end

      initializer 'demo_mode' do |app|
        if app.config.respond_to?(:autoloader) && app.config.autoloader.to_sym == :zeitwerk
          require 'zeitwerk/version'
          raise 'DemoMode only supports Zeitwerk::VERSION >= 2.4.2' unless Gem::Version.new(Zeitwerk::VERSION) >= Gem::Version.new('2.4.2')

          Rails.autoloaders.main.on_load(DemoMode.app_base_controller_name) do
            DemoMode.app_base_controller_name.constantize.include Demoable
          end
        else
          ActiveSupport.on_load(:action_controller) do
            DemoMode.app_base_controller_name.constantize.include Demoable
          end
        end
      end
    end

    initializer 'demo_mode.assets' do |app|
      app.config.assets.precompile << 'demo_mode/application.css'
      app.config.assets.precompile << 'demo_mode/application.js'
      app.config.assets.precompile << 'demo_mode/icon--user.png'
      app.config.assets.precompile << 'demo_mode/icon--users.png'
      app.config.assets.precompile << 'demo_mode/icon--tophat.png'
      app.config.assets.precompile << 'demo_mode/loader.png'
    end
  end
end
