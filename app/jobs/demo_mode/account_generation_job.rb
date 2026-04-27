# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      session.with_lock do
        session.update!(status: 'processing') if session.failed?
        persona = session.persona
        raise "Unknown persona: #{session.persona_name}" if persona.blank?

        signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
        session.update!(signinable: signinable, persona_checksum: persona.file_checksum)

        if session.claimed_at?
          persona.effective_at_claim_callback(session.variant)&.call(signinable)
        end

        new_status = session.claimed_at? ? 'in_use' : 'available'
        session.update!(status: new_status)
      end
    rescue StandardError => e
      session.update!(status: 'failed')
      raise e
    end
  end
end
