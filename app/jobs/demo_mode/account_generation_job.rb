# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      session.with_lock do
        persona = session.persona
        raise "Unknown persona: #{session.persona_name}" if persona.blank?

        signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
        session.update!(signinable: signinable)
      end
      if session.signinable.blank?
        session.update!(error: 'Failed to create signinable persona!')
        raise "Failed to create signinable persona!"
      end
      end
      end
    end
  end
end
