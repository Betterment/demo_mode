# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::SequenceTracker do
  describe '.track' do
    it 'returns an array of recorded sequences' do
      result = described_class.track do
        described_class.record(DummyUser, :email, 'test@example.com')
        described_class.record(DummyUser, :name, 'Test User')
      end

      expect(result).to eq([
        { class: 'DummyUser', attribute: 'email', value: 'test@example.com' },
        { class: 'DummyUser', attribute: 'name', value: 'Test User' }
      ])
    end

    it 'returns an empty array when no sequences are recorded' do
      result = described_class.track { }
      expect(result).to eq([])
    end

    it 'is thread-isolated' do
      results = []
      threads = 2.times.map do |i|
        Thread.new do
          described_class.track do
            described_class.record(DummyUser, :id, i)
            sleep 0.01
            results << Thread.current[DemoMode::SequenceTracker::THREAD_KEY].dup
          end
        end
      end
      threads.each(&:join)

      expect(results[0].length).to eq(1)
      expect(results[1].length).to eq(1)
      expect(results[0]).not_to eq(results[1])
    end

    it 'cleans up thread-local state after completion' do
      described_class.track { }
      expect(described_class.tracking?).to be false
    end

    it 'cleans up thread-local state even on exception' do
      expect {
        described_class.track { raise 'test error' }
      }.to raise_error('test error')

      expect(described_class.tracking?).to be false
    end
  end

  describe '.record' do
    it 'does nothing when not tracking' do
      # Should not raise, just no-op
      expect { described_class.record(DummyUser, :email, 'test@example.com') }.not_to raise_error
    end

    it 'serializes numeric values' do
      result = described_class.track do
        described_class.record(DummyUser, :id, 42)
      end

      expect(result.first[:value]).to eq(42)
    end

    it 'serializes Date values to ISO8601' do
      result = described_class.track do
        described_class.record(DummyUser, :created_at, Date.new(2024, 1, 15))
      end

      expect(result.first[:value]).to eq('2024-01-15')
    end

    it 'serializes Time values to ISO8601' do
      time = Time.utc(2024, 1, 15, 10, 30, 0)
      result = described_class.track do
        described_class.record(DummyUser, :created_at, time)
      end

      expect(result.first[:value]).to eq('2024-01-15T10:30:00Z')
    end

    it 'serializes objects to string' do
      object = Object.new
      result = described_class.track do
        described_class.record(DummyUser, :data, object)
      end

      expect(result.first[:value]).to eq(object.to_s)
    end
  end

  describe '.tracking?' do
    it 'returns true inside track block' do
      described_class.track do
        expect(described_class.tracking?).to be true
      end
    end

    it 'returns false outside track block' do
      expect(described_class.tracking?).to be false
    end
  end
end
