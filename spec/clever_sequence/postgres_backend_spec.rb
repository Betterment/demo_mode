# frozen_string_literal: true

require 'spec_helper'
require 'demo_mode/clever_sequence/postgres_backend'

RSpec.describe CleverSequence::PostgresBackend do
  let(:klass) { Widget }
  let(:attribute) { :integer_column }
  let(:block) { ->(i) { i } }

  before do
    skip 'PostgresBackend requires PostgreSQL' unless ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  end

  context 'when sequence exists' do
    let(:sequence_name) { described_class.sequence_name(klass, attribute) }

    before do
      ActiveRecord::Base.connection.execute(
        "CREATE SEQUENCE IF NOT EXISTS #{sequence_name} START WITH 1",
      )
    end

    after do
      ActiveRecord::Base.connection.execute(
        "DROP SEQUENCE IF EXISTS #{sequence_name}",
      )
    end

    it 'returns the next value' do
      expect(described_class.nextval(klass, attribute, block)).to eq 1
      expect(described_class.nextval(klass, attribute, block)).to eq 2
      expect(described_class.nextval(klass, attribute, block)).to eq 3
    end

    it 'returns sequential integers from PostgreSQL sequence' do
      result_1 = described_class.nextval(klass, attribute, block)
      result_2 = described_class.nextval(klass, attribute, block)
      expect(result_2).to eq(result_1 + 1)
    end

    it 'caches sequence existence checks' do
      described_class.reset!

      execute_calls = []
      allow(ActiveRecord::Base.connection).to receive(:execute).and_wrap_original do |method, *args|
        execute_calls << args[0]
        method.call(*args)
      end

      described_class.nextval(klass, attribute, block)

      described_class.nextval(klass, attribute, block)

      information_schema_queries = execute_calls.grep(/information_schema\.sequences/)
      expect(information_schema_queries.count).to eq 1

      nextval_queries = execute_calls.grep(/SELECT nextval/)
      expect(nextval_queries.count).to eq 2
    end

    it 'caches a SequenceResult::Exists entry' do
      described_class.reset!

      described_class.nextval(klass, attribute, block)

      cached = described_class.sequence_cache[sequence_name]
      expect(cached).to be_a(CleverSequence::PostgresBackend::SequenceResult::Exists)
      expect(cached.sequence_name).to eq sequence_name
    end

    context 'when existing data conflicts with sequence start value' do
      before do
        described_class.reset!
        # Create widgets with integer_column values 1, 2, 3, 4, 5
        (1..5).each { |i| Widget.create!(integer_column: i) }
      end

      after do
        Widget.delete_all
      end

      context 'without sequence adjustment' do
        it 'does not adjust sequence and returns conflicting values' do
          # Without adjustment, sequence returns 1, 2, 3... which conflict
          result = described_class.nextval(klass, attribute, block)
          expect(result).to eq 1
        end
      end

      context 'with sequence adjustment' do
        it 'adjusts sequence to skip past existing values' do
          described_class.with_sequence_adjustment do
            # Sequence starts at 1, but values 1-5 already exist
            # First nextval should return 6 (after adjustment)
            result = described_class.nextval(klass, attribute, block)
            expect(result).to eq 6
          end
        end

        it 'returns sequential values after adjustment' do
          described_class.with_sequence_adjustment do
            result_1 = described_class.nextval(klass, attribute, block)
            result_2 = described_class.nextval(klass, attribute, block)
            result_3 = described_class.nextval(klass, attribute, block)

            expect(result_1).to eq 6
            expect(result_2).to eq 7
            expect(result_3).to eq 8
          end
        end

        it 'only adjusts sequence on first use' do
          execute_calls = []
          allow(ActiveRecord::Base.connection).to receive(:execute).and_wrap_original do |method, *args|
            execute_calls << args[0]
            method.call(*args)
          end

          described_class.with_sequence_adjustment do
            described_class.nextval(klass, attribute, block)
            described_class.nextval(klass, attribute, block)
            described_class.nextval(klass, attribute, block)
          end

          setval_queries = execute_calls.grep(/setval/)
          expect(setval_queries.count).to eq 1
        end
      end
    end

    context 'when sequence is already past existing data' do
      before do
        described_class.reset!
        # Create widgets with low values
        Widget.create!(integer_column: 1)
        Widget.create!(integer_column: 2)
        # Advance the sequence past existing data
        ActiveRecord::Base.connection.execute(
          "SELECT setval('#{sequence_name}', 100)",
        )
      end

      after do
        Widget.delete_all
      end

      it 'does not go backwards' do
        described_class.with_sequence_adjustment do
          # Sequence is at 100, existing data only goes to 2
          # Should return 101, not 3
          result = described_class.nextval(klass, attribute, block)
          expect(result).to eq 101
        end
      end
    end

    context 'when no existing data' do
      before do
        described_class.reset!
        Widget.delete_all
      end

      it 'returns values starting from 1' do
        result = described_class.nextval(klass, attribute, block)
        expect(result).to eq 1
      end
    end
  end

  context 'when sequence does not exist' do
    let(:sequence_name) { described_class.sequence_name(klass, :nonexistent_column) }
    let(:nonexistent_attribute) { :nonexistent_column }

    before do
      # Ensure sequence doesn't exist
      ActiveRecord::Base.connection.execute(
        "DROP SEQUENCE IF EXISTS #{sequence_name}",
      )

      described_class.reset!
    end

    context 'when enforce_sequences_exist is true' do
      before { CleverSequence.enforce_sequences_exist = true }
      after { CleverSequence.enforce_sequences_exist = false }

      it 'raises a SequenceNotFoundError' do
        error = nil
        expect {
          described_class.nextval(klass, nonexistent_attribute, block)
        }.to raise_error(CleverSequence::PostgresBackend::SequenceNotFoundError) { |e| error = e }

        expect(error.sequence_name).to eq sequence_name
        expect(error.klass).to eq klass
        expect(error.attribute).to eq nonexistent_attribute
        expect(error.message).to include(sequence_name)
      end

      it 'caches a SequenceResult::Missing entry even when raising' do
        expect {
          described_class.nextval(klass, nonexistent_attribute, block)
        }.to raise_error(CleverSequence::PostgresBackend::SequenceNotFoundError)

        cached = described_class.sequence_cache[sequence_name]
        expect(cached).to be_a(CleverSequence::PostgresBackend::SequenceResult::Missing)
        expect(cached.sequence_name).to eq sequence_name
        expect(cached.klass).to eq klass
        expect(cached.attribute).to eq nonexistent_attribute
        expect(cached.calculated_start_value).to eq 1
      end
    end

    context 'when enforce_sequences_exist is false' do
      before { CleverSequence.enforce_sequences_exist = false }

      it 'calculates a new sequence value' do
        result = described_class.nextval(klass, nonexistent_attribute, block)
        expect(result).to eq 1
      end

      it 'caches a SequenceResult::Missing entry with migration data' do
        described_class.nextval(klass, nonexistent_attribute, block)

        cached = described_class.sequence_cache[sequence_name]
        expect(cached).to be_a(CleverSequence::PostgresBackend::SequenceResult::Missing)
        expect(cached.sequence_name).to eq sequence_name
        expect(cached.klass).to eq klass
        expect(cached.attribute).to eq nonexistent_attribute
        expect(cached.calculated_start_value).to eq 1
      end
    end
  end

  describe '.starting_value' do
    it 'returns 0 when the column does not exist' do
      expect(described_class.starting_value(klass, :nonexistent, block)).to eq 0
    end

    it 'uses LowerBoundFinder when the column exists' do
      allow(klass).to receive(:find_by_integer_column).and_return(nil)
      allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)

      expect(described_class.starting_value(klass, :integer_column, block)).to eq 1
    end
  end

  describe '.reset!' do
    it 'clears the sequence cache' do
      described_class.sequence_cache['some_key'] = 'value'
      described_class.reset!
      expect(described_class.sequence_cache).to be_empty
    end
  end

  describe 'thread safety' do
    let(:sequence_name) { described_class.sequence_name(klass, :nonexistent_column) }
    let(:nonexistent_attribute) { :nonexistent_column }

    before do
      ActiveRecord::Base.connection.execute(
        "DROP SEQUENCE IF EXISTS #{sequence_name}",
      )
      described_class.reset!
      CleverSequence.enforce_sequences_exist = false
    end

    after do
      CleverSequence.enforce_sequences_exist = false
    end

    it 'returns unique values when nextval is called concurrently from multiple threads' do
      thread_count = 10

      # Seed the cache with a Missing entry so all threads exercise the
      # cached read-increment-write path without needing DB connections.
      described_class.nextval(klass, nonexistent_attribute, block)

      go = false

      threads = thread_count.times.map do
        Thread.new do
          Thread.pass until go
          described_class.nextval(klass, nonexistent_attribute, block)
        end
      end

      go = true

      values = threads.map(&:value)

      expect(values).to all(be_an(Integer))
      expect(values.uniq.size).to eq(thread_count),
        "Expected #{thread_count} unique values but got duplicates: #{values.sort}"
    end
  end

  describe '.with_sequence_adjustment' do
    it 'enables adjustment within the block' do
      enabled_inside = nil
      described_class.with_sequence_adjustment do
        enabled_inside = Thread.current[:clever_sequence_adjust_sequences_enabled]
      end
      expect(enabled_inside).to be true
    end

    it 'disables adjustment after the block' do
      described_class.with_sequence_adjustment { nil }
      expect(Thread.current[:clever_sequence_adjust_sequences_enabled]).to be false
    end

    it 'disables adjustment even if the block raises' do
      expect {
        described_class.with_sequence_adjustment { raise 'oops' }
      }.to raise_error('oops')
      expect(Thread.current[:clever_sequence_adjust_sequences_enabled]).to be false
    end
  end

  describe '.sequence_name' do
    it 'generates correct format' do
      name = described_class.sequence_name(klass, :email)
      expect(name).to eq 'cs_widgets_email'
    end

    it 'sanitizes special characters' do
      allow(klass).to receive(:table_name).and_return('my-table$name')
      name = described_class.sequence_name(klass, :'my-attr$name')
      expect(name).to eq 'cs_my_table_name_my_attr_name'
    end

    it 'truncates long table and attribute names' do
      allow(klass).to receive(:table_name).and_return('a' * 50)
      name = described_class.sequence_name(klass, 'b' * 50)
      expect(name.length).to eq 64
      expect(name).to start_with('cs_')
      expect(name).to match(/^cs_a{30}_b{30}$/)
    end
  end
end
