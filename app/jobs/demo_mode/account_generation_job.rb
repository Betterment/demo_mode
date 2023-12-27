# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session)
      session.with_lock do
        persona = persona(session)
        raise "Unknown persona: #{session.persona_name}" if persona.blank?

        signinable = persona.generate!(variant: session.variant, password: session.signinable_password)
        session.update!(signinable: signinable)
      end
      raise "Failed to create signinable persona!" if session.signinable.blank?
    end

    private

    def persona(session)
      DemoMode.personas.find { |p| p.name.to_s == session.persona_name.to_s }
    end
  end
end
