# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::PoolHydrationJob do
  before do
    DemoMode.configure do
      personas_path 'config/system-test-personas'
      minimum_pool_size 2
    end
  end

  describe '#perform', with_queue_adapter: :test do
    context 'when no persona_name/variant is given (orchestrator mode)' do
      it 'enqueues a leaf job for each persona/variant combination' do
        expect { described_class.perform_now }.to have_enqueued_job(described_class).exactly(5).times
      end

      it 'skips persona/variant combinations already at target' do
        s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
        s.signinable = DummyUser.create!(name: 'test')
        s.status = 'available'
        s.save!(validate: false)
        2.times do
          s = DemoMode::Session.new(persona_name: :zendaya, variant: 'default', pool_session: true)
          s.signinable = DummyUser.create!(name: 'test')
          s.status = 'available'
          s.save!(validate: false)
        end

        expect { described_class.perform_now }.to have_enqueued_job(described_class).exactly(4).times
      end

      it 'passes a custom count through to leaf jobs' do
        expect {
          described_class.perform_now(count: 5)
        }.to have_enqueued_job(described_class).with(hash_including(count: 5)).exactly(5).times
      end

      it 'emits demo_mode.pool.depth for each persona/variant with current available count and target' do
        s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
        s.signinable = DummyUser.create!(name: 'test')
        s.status = 'available'
        s.save!(validate: false)

        expect {
          described_class.perform_now
        }.to emit_notification('demo_mode.pool.depth')
          .with_payload(persona_name: 'the_everyperson', variant: 'default', available: 1, target: 2)
      end

      it 'emits demo_mode.pool.depth with available: 0 when pool is empty' do
        expect {
          described_class.perform_now
        }.to emit_notification('demo_mode.pool.depth')
          .with_payload(persona_name: 'the_everyperson', variant: 'default', available: 0, target: 2)
      end
    end

    context 'when persona_name and variant are given (leaf mode)' do
      it 'creates one session and enqueues a follow-up job when still under target' do
        expect {
          described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
        }.to have_enqueued_job(described_class)
          .with(persona_name: :the_everyperson, variant: 'default', count: nil)

        expect(DemoMode::Session.available_for(:the_everyperson, 'default').count).to eq(1)
      end

      it 'creates one session and does not enqueue a follow-up when target is reached' do
        s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
        s.signinable = DummyUser.create!(name: 'test')
        s.status = 'available'
        s.persona_checksum = s.persona&.file_checksum
        s.save!(validate: false)

        expect {
          described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
        }.not_to have_enqueued_job(described_class)

        expect(DemoMode::Session.available_for(:the_everyperson, 'default').count).to eq(2)
      end

      it 'does nothing when the pool is already at target' do
        2.times do
          s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
          s.signinable = DummyUser.create!(name: 'test')
          s.status = 'available'
          s.persona_checksum = s.persona&.file_checksum
          s.save!(validate: false)
        end

        expect {
          described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
        }.not_to have_enqueued_job(described_class)

        expect(DemoMode::Session.available_for(:the_everyperson, 'default').count).to eq(2)
      end

      it 'uses a custom count over minimum_pool_size' do
        expect {
          described_class.perform_now(persona_name: :the_everyperson, variant: 'default', count: 3)
        }.to have_enqueued_job(described_class)
          .with(persona_name: :the_everyperson, variant: 'default', count: 3)
      end

      it 'does not count stale sessions toward the pool target' do
        2.times do
          s = DemoMode::Session.new(persona_name: :the_everyperson, variant: 'default', pool_session: true)
          s.signinable = DummyUser.create!(name: 'test')
          s.status = 'available'
          s.persona_checksum = 'stale_checksum'
          s.save!(validate: false)
        end

        expect {
          described_class.perform_now(persona_name: :the_everyperson, variant: 'default')
        }.to have_enqueued_job(described_class)
          .with(persona_name: :the_everyperson, variant: 'default', count: nil)
      end
    end
  end
end
