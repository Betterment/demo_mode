# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      session.with_lock do
        persona = session.persona
        raise "Unknown persona: #{session.persona_name}" if persona.blank?

        signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
        new_status = session.claimed_at? ? 'in_use' : 'available'
        session.update!(signinable: signinable, status: new_status, persona_checksum: persona.file_checksum)
      end
    rescue StandardError => e
      session.update!(status: 'failed')
      raise e
    end
  end
end
