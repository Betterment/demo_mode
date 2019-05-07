require 'rails/generators/base'

module DemoMode
  class InstallGenerator < Rails::Generators::Base
    desc 'Copies initial demo mode files to your application.'
    source_root File.expand_path('../templates', __dir__)

    def install
      template 'initializer.rb', 'config/initializers/demo_mode.rb'
      template 'sample_persona.rb', 'config/personas/sample_persona.rb'
      rake 'demo_mode:install:migrations'
    end
  end
end
