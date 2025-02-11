# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      session.with_lock do
        persona = session.persona
        if persona.blank?
          session.update!(error: "Unknown persona: #{session.persona_name}")
          raise "Unknown persona: #{session.persona_name}"
        end

        begin
          signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
          session.update!(signinable: signinable)
        rescue StandardError => e
          session.update!(failed_at: Time.current)
          Rails.logger.error(e.message)
        end
      end
      raise "Failed to create signinable persona!" if session.signinable.blank?
    end
  end
end
