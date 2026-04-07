# frozen_string_literal: true

module DemoMode
  class Session < ActiveRecord::Base
    include ::SteadyState

    attribute :variant, default: :default

    attr_accessor :pool_session

    steady_state :status do
      state 'processing', default: true
      state 'available', from: 'processing'
      state 'in_use', from: %w(processing available)
      state 'failed', from: 'processing'
    end

    scope :unclaimed, -> { where(claimed_at: nil) }
    scope :claimed,   -> { where.not(claimed_at: nil) }
    scope :available_for, ->(persona_name, variant) {
      available.unclaimed.where(persona_name: persona_name, variant: variant)
    }

    validates :persona_name, :variant, presence: true
    validates :persona, presence: { message: :required }, on: :create, if: :persona_name?
    validates :claimed_at, absence: true, if: :available?
    validates :claimed_at, presence: true, if: :in_use?
    validate :terminal_status_requires_signinable

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
      available? || in_use? ? metadata.call(self) : {}
    end

    # Heads up: finding a persona is not guaranteed (e.g. past sessions)
    def persona
      DemoMode.personas.find { |p| p.name.to_s == persona_name.to_s }
    end

    def self.claim_for(**opts)
      transaction do
        prototype = new(**opts)
        available_for(prototype.persona_name, prototype.variant)
          .lock
          .first_or_initialize(persona_name: prototype.persona_name, variant: prototype.variant)
          .tap(&:claim!)
      end
    end

    def claim!
      if new_record?
        self.claimed_at = Time.zone.now
        save!
      else
        lock!.update!(claimed_at: Time.zone.now, status: 'in_use')
      end
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

    def terminal_status_requires_signinable
      if (available? || in_use?) && signinable.blank?
        errors.add(:status, 'cannot be available or in_use if signinable is not present')
      end
    end
  end
end
