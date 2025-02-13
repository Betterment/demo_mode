# frozen_string_literal: true

module DemoMode
  class Session < ActiveRecord::Base
    attribute :variant, default: :default
    attribute :status, default: 'processing'

    validates :persona_name, :variant, presence: true
    validates :persona, presence: { message: :required }, on: :create, if: :persona_name?
    validates :status, inclusion: { in: %w(processing successful failed) }
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

    # Heads up: finding a persona is not guaranteed (e.g. past sessions)
    def persona
      DemoMode.personas.find { |p| p.name.to_s == persona_name.to_s }
    end

    def save_and_generate_account!(**options)
      transaction do
        save!
        AccountGenerationJob.perform_now(self, **options)
      end
    end

    def save_and_generate_account_later!(**options)
      transaction do
        save!
        AccountGenerationJob.perform_later(self, **options)
      end
    end

    def processing?
      status == 'processing'
    end

    private

    def set_password!
      self.signinable_password ||= DemoMode.current_password
    end
  end
end
