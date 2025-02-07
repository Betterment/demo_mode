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
        rescue StandardError => e
          session.update!(error: e.message)
        end
        session.update!(signinable: signinable)
      end
      if session.signinable.blank?
        session.update!(error: 'Failed to create signinable persona!')
        raise "Failed to create signinable persona!"
      end
    end
  end
end
