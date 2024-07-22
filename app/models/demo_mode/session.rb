# frozen_string_literal: true

module DemoMode
  class Session < ActiveRecord::Base
    attribute :variant, default: :default

    validates :persona_name, :variant, presence: true
    validate :persona_must_exist, on: :create
    belongs_to :signinable, polymorphic: true, optional: true

    before_create :set_password!

    delegate :begin_demo,
             :custom_sign_in?,
             :display_credentials?,
             to: :persona,
             allow_nil: true

    def signinable_username
      signinable.public_send(DemoMode.signinable_username_method)
    end

    private

    def set_password!
      self.signinable_password ||= DemoMode.current_password
    end

    # Heads up: finding a persona is not guaranteed (e.g. past sessions)
    def persona
      DemoMode.personas.find { |p| p.name.to_s == persona_name.to_s }
    end

    def persona_must_exist
      errors.add(:persona_name, 'does not exist') if persona_name? && persona.nil?
    end
  end
end
