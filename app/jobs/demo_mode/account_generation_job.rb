# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      session.with_lock do
        persona = session.persona
        raise "Unknown persona: #{session.persona_name}" if persona.blank?

        begin
          signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
        rescue StandardError => e
          session.update!(error: e.message)
        end
        session.update!(signinable: signinable)
      end
      raise "Failed to create signinable persona!" if session.signinable.blank?
    end
  end
end
