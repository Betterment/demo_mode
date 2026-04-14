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
      current_counts = DemoMode::Session.available.group(:persona_name, :variant).count

      DemoMode.personas.each do |persona|
        persona.variants.each_key do |v|
          next if (current_counts[[persona.name.to_s, v.to_s]] || 0) >= target

          PoolHydrationJob.perform_later(persona_name: persona.name, variant: v, count: count)
        end
      end
    end

    def hydrate(persona_name, variant, count)
      return unless DemoMode.personas.any? { |p| p.name.to_s == persona_name.to_s && p.variants.key?(variant) }

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
