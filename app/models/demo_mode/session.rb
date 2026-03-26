# frozen_string_literal: true

module DemoMode
  class Session < ActiveRecord::Base
    attribute :variant, default: :default

    attr_accessor :pool_session

    enum :status, { processing: 'processing', successful: 'successful', failed: 'failed' }, default: 'processing'

    scope :unclaimed, -> { where(claimed_at: nil) }
    scope :claimed,   -> { where.not(claimed_at: nil) }
    scope :available_for, ->(persona_name, variant) {
      successful.unclaimed.where(persona_name: persona_name, variant: variant)
    }

    validates :persona_name, :variant, presence: true
    validates :persona, presence: { message: :required }, on: :create, if: :persona_name?
    validate :successful_status_requires_signinable

    belongs_to :signinable, polymorphic: true, optional: true

    before_create :set_password!
    before_create :claim_if_not_pooled!

    delegate :begin_demo,
      :custom_sign_in?,
      :display_credentials?,
      :metadata,
      to: :persona,
      allow_nil: true

    def signinable_username
      signinable.public_send(DemoMode.signinable_username_method)
    end

    def signinable_metadata
      successful? ? metadata.call(self) : {}
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

    private

    def set_password!
      self.signinable_password ||= DemoMode.current_password
    end

    def claim_if_not_pooled!
      self.claimed_at ||= Time.zone.now unless pool_session
    end

    def successful_status_requires_signinable
      if status == 'successful' && signinable.blank?
        errors.add(:status, 'cannot be successful if signinable is not present')
      end
    end
  end
end
