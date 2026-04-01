# frozen_string_literal: true

module DemoMode
  class PoolHydrationJob < DemoMode.base_job_name.constantize
    def perform(persona_name: nil, variant: nil, count: nil)
      if persona_name && variant
        hydrate(persona_name, variant, count)
      else
        DemoMode.personas.each do |persona|
          persona.variants.each_key do |v|
            hydrate(persona.name, v, count)
          end
        end
      end
    end

    private

    def hydrate(persona_name, variant, count)
      target = count || DemoMode.minimum_pool_size
      deficit = target - DemoMode::Session.pool_count(persona_name, variant)
      deficit.times do
        DemoMode::Session.new(persona_name: persona_name, variant: variant, pool_session: true)
          .save_and_generate_account_later!
      end
    end
  end
end
