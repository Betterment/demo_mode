# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::PoolHydrationJob do
  before do
    DemoMode.configure do
      personas_path 'config/system-test-personas'
      minimum_pool_size 2
    end
  end

  describe '#perform', :with_queue_adapter => :test do
    it 'enqueues generation jobs for all persona/variant combinations' do
      expect { described_class.perform_now }.to have_enqueued_job(DemoMode::AccountGenerationJob).exactly(10).times
    end

    it 'enqueues only for the specified persona/variant when given' do
      expect {
        described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
      }.to have_enqueued_job(DemoMode::AccountGenerationJob).exactly(2).times
    end

    it 'enqueues no jobs when pool is already at minimum' do
      2.times do
        s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
        s.signinable = DummyUser.create!(name: 'test')
        s.status = 'available'
        s.save!(validate: false)
      end

      expect {
        described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
      }.not_to have_enqueued_job(DemoMode::AccountGenerationJob)
    end

    it 'uses the custom count over minimum_pool_size' do
      expect {
        described_class.perform_now(persona_name: :the_everyperson, variant: 'default', count: 3)
      }.to have_enqueued_job(DemoMode::AccountGenerationJob).exactly(3).times
    end
  end
end
