# frozen_string_literal: true

require 'active_model'

module DemoMode
  class Persona
    include ActiveModel::Model

    attr_accessor :name

    validates :name, presence: true
    validate :persona_must_have_at_least_one_feature

    def icon(name_or_path = nil, &block)
      if block
        @icon = block
      elsif name_or_path
        @path = ICONS.fetch(name_or_path, name_or_path)
        path = @path
        @icon = ->(_) { image_tag path }
      else
        @icon ||= DemoMode.icon
      end
    end

    def features
      @features ||= []
    end

    def begin_demo(&block)
      if block
        @begin_demo = block
      else
        @begin_demo || proc do
          sign_in @session.signinable
          redirect_to main_app.root_path
        end
      end
    end

    def metadata(&block)
      if block
        @metadata = block
      else
        @metadata ||= ->(_) { {} }
      end
    end

    def sign_in_as(&signinable_generator)
      variant(:default) do
        sign_in_as(&signinable_generator)
      end
    end

    def variant(name, &block)
      variants[name] = Variant.new(name: name).tap do |v|
        v.instance_eval(&block)
      end
    end

    def variants
      @variants ||= {}.with_indifferent_access
    end

    def generate!(variant: :default, password: nil, options: {})
      ActiveSupport::Notifications.instrument('demo_mode.persona.generate', name: name, variant: variant) do
        variant = variants[variant]
        CleverSequence.reset! if defined?(CleverSequence)
        DemoMode.current_password = password if password
        DemoMode.around_persona_generation.call(variant.signinable_generator, **options)
      ensure
        DemoMode.current_password = nil
      end
    end

    def callout(callout = true) # rubocop:disable Style/OptionalBooleanParameter
      @callout = callout
    end

    def callout?
      instance_variable_defined?(:@callout) && @callout
    end

    def display_credentials(display_credentials = true) # rubocop:disable Style/OptionalBooleanParameter
      @display_credentials = display_credentials
    end

    def display_credentials?
      if instance_variable_defined?(:@display_credentials)
        @display_credentials
      else
        DemoMode.display_credentials?
      end
    end

    def custom_sign_in?
      display_credentials? || @begin_demo.present?
    end

    def css_class
      "dm-Persona--#{name.to_s.camelize(:lower)}"
    end

    private

    def persona_must_have_at_least_one_feature
      errors.add(:base, <<~ERR) unless features.count >= 1
        Persona must have at least one feature.

          For example:

          DemoMode.add_persona do
            features << 'has a cool hat'

            ...
          end
      ERR
    end

    Variant = Struct.new(:name, keyword_init: true) do
      def sign_in_as(&signinable_generator)
        @signinable_generator = signinable_generator
      end

      def title
        name.is_a?(Symbol) ? name.to_s.titleize : name.to_s
      end

      attr_reader :signinable_generator
    end
  end
end
