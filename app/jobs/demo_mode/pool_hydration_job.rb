# frozen_string_literal: true

module DemoMode
  class PoolHydrationJob < DemoMode.base_job_name.constantize
    def perform(persona_name: nil, variant: nil, count: nil)
      if persona_name && variant
        hydrate(persona_name, variant, count)
      else
        orchestrate(count)
      end
    end

    private

    def orchestrate(count)
      target = count || DemoMode.minimum_pool_size

      DemoMode.personas.each do |persona|
        next unless persona.allow_in_pool?

        persona.variants.each do |v, variant|
          next unless variant.allow_in_pool?

          available = DemoMode::Session.available_for(persona.name, v).count
          ActiveSupport::Notifications.instrument('demo_mode.pool.depth',
            persona_name: persona.name, variant: v, value: target - available)
          next if available >= target

          PoolHydrationJob.perform_later(persona_name: persona.name, variant: v, count: count)
        end
      end
    end

    def hydrate(persona_name, variant, count)
      persona = DemoMode.personas.find { |p| p.name.to_s == persona_name.to_s && p.variants.key?(variant) }

      return unless persona&.allow_in_pool?

      target = count || DemoMode.minimum_pool_size
      return if DemoMode::Session.available_for(persona_name, variant).count >= target

      DemoMode::Session.new(persona_name: persona_name, variant: variant, pool_session: true)
        .save_and_generate_account!

      if DemoMode::Session.available_for(persona_name, variant).count < target
        PoolHydrationJob.perform_later(persona_name: persona_name, variant: variant, count: count)
      end
    end
  end
end
