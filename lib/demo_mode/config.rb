require_relative 'concerns/configurable'

module DemoMode
  class Config
    include Configurable

    configurable_value(:current_user_method) { :current_user }
    configurable_value(:splash_base_controller_name) { 'ActionController::Base' }
    configurable_value(:app_base_controller_name) { 'ApplicationController' }
    configurable_value(:base_job_name) { 'ActiveJob::Base' }
    configurable_value(:signinable_username_method) { :email }
    configurable_value(:personas_path) { 'config/personas' }
    configurable_value(:session_timeout) { 30.minutes }
    configurable_boolean(:display_credentials)
    configurations << :logo
    configurations << :loader
    configurations << :icon
    configurations << :password
    configurations << :around_persona_generation
    configurations << :personas
    configurations << :sign_up_path
    configurations << :sign_in_path

    def self.app_name
      if Rails::VERSION::MAJOR >= 6
        Rails.application.class.module_parent.name
      else
        Rails.application.class.parent.name
      end
    end

    def logo(&block)
      if block
        @logo = block
      else
        @logo ||= ->(_) { content_tag(:strong, DemoMode::Config.app_name) }
      end
    end

    def loader(&block)
      if block
        @loader = block
      else
        @loader ||= ->(_) { image_tag('demo_mode/loader.png') }
      end
    end

    def icon(name_or_path = nil, &block)
      if block
        @icon = block
      elsif name_or_path
        @path = name_or_path.is_a?(Symbol) ? "demo_mode/icon--#{name_or_path}" : name_or_path
      else
        @path ||= 'demo_mode/icon--user'
        path = @path
        @icon ||= ->(_) { image_tag path }
      end
    end

    WORDS = %w(area book business case child company country day eye fact family government group home job life lot money month night number
               office people phone place point problem program question right room school state story student study system thing time water
               way week word work world year).freeze

    def password(&block)
      if block
        @password = block
      else
        @password ||= -> {
          "#{WORDS.sample}#{WORDS.sample.upcase}#{WORDS.sample}!#{Array.new(2) { rand(10).to_s }.join}"
        }
      end
    end

    def around_persona_generation(&block)
      if block
        @around_persona_generation = block
      else
        @around_persona_generation ||= :call.to_proc
      end
    end

    def sign_in_path(ctx = nil, &block)
      if block
        @sign_in_path = block
      elsif @sign_in_path
        ctx.instance_eval(&@sign_in_path)
      end
    end

    def sign_up_path(ctx = nil, &block)
      if block
        @sign_up_path = block
      elsif @sign_up_path
        ctx.instance_eval(&@sign_up_path)
      end
    end

    def persona(persona_name, &block)
      personas << Persona.new(name: persona_name).tap do |p|
        p.instance_eval(&block)
        p.validate!
      end
    end

    def personas
      unless instance_variable_defined?(:@personas)
        @personas = []
        auto_load_personas!
      end
      @personas
    end

    private

    def auto_load_personas!
      Dir.glob(Rails.root.join(personas_path, '**', '*.rb')).sort.each do |persona|
        raise <<~ERROR if File.readlines(persona).grep(/DemoMode\.add_persona/).empty?
          This file does not define a persona: #{persona}\n
          Please use `DemoMode.add_persona`
        ERROR

        load(persona)
      end
    end
  end
end
