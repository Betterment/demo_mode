# frozen_string_literal: true

module DemoMode
  class AccountGenerationJob < DemoMode.base_job_name.constantize
    def perform(session, **options)
      start_time = Time.current
      start_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      log_generation_started(session, start_time)

      sequences_used = SequenceTracker.track do
        session.with_lock do
          persona = session.persona
          raise "Unknown persona: #{session.persona_name}" if persona.blank?

          signinable = persona.generate!(variant: session.variant, password: session.signinable_password, options: options)
          session.update!(signinable: signinable, status: 'successful')
        end
      end

      end_time = Time.current
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_monotonic) * 1000).round(2)

      log_generation_completed(session, start_time, end_time, duration_ms, sequences_used)
    rescue StandardError => e
      end_time = Time.current
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_monotonic) * 1000).round(2) if start_monotonic

      session.update!(status: 'failed')
      log_generation_failed(session, start_time, end_time, duration_ms, e)
      raise e
    end

    private

    def log_generation_started(session, start_time)
      log_event('demo_mode.account_generation.started', :info,
        session_id: session.id,
        persona_name: session.persona_name,
        variant: session.variant&.to_s,
        start_time: start_time.iso8601(3))
    end

    def log_generation_completed(session, start_time, end_time, duration_ms, sequences_used)
      log_event('demo_mode.account_generation.completed', :info,
        session_id: session.id,
        persona_name: session.persona_name,
        variant: session.variant&.to_s,
        start_time: start_time.iso8601(3),
        end_time: end_time.iso8601(3),
        duration_ms: duration_ms,
        signinable_id: session.signinable_id,
        signinable_type: session.signinable_type,
        sequences_used_count: sequences_used.size,
        sequences_used: sequences_used)
    end

    def log_generation_failed(session, start_time, end_time, duration_ms, error)
      log_event('demo_mode.account_generation.failed', :error,
        session_id: session.id,
        persona_name: session.persona_name,
        variant: session.variant&.to_s,
        start_time: start_time&.iso8601(3),
        end_time: end_time&.iso8601(3),
        duration_ms: duration_ms,
        error_class: error.class.name,
        error_message: error.message)
    end

    def log_event(event, level, **payload)
      log_data = { event: event, **payload }
      Rails.logger.public_send(level, log_data.to_json)
    end
  end
end
