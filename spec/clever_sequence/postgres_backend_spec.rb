# frozen_string_literal: true

require 'spec_helper'

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
      described_class.instance_variable_set(:@sequence_cache, nil)

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
  end

  context 'when sequence does not exist' do
    let(:sequence_name) { described_class.sequence_name(klass, :nonexistent_column) }
    let(:nonexistent_attribute) { :nonexistent_column }

    before do
      # Ensure sequence doesn't exist
      ActiveRecord::Base.connection.execute(
        "DROP SEQUENCE IF EXISTS #{sequence_name}",
      )

      described_class.instance_variable_set(:@sequence_cache, nil)
    end

    context 'when throw_if_sequence_not_found is true' do
      it 'throws a SequenceNotFoundError' do
        error = nil
        expect {
          described_class.nextval(klass, nonexistent_attribute, block, throw_if_sequence_not_found: true)
        }.to raise_error(CleverSequence::PostgresBackend::SequenceNotFoundError) { |e| error = e }

        expect(error.sequence_name).to eq sequence_name
        expect(error.klass).to eq klass
        expect(error.attribute).to eq nonexistent_attribute
        expect(error.calculated_start_value).not_to be_nil
        expect(error.message).to include(sequence_name)
      end

      it 'sends notification when sequence is not found' do
        described_class.instance_variable_set(:@sequence_cache, nil)

        events = []
        subscriber = ActiveSupport::Notifications.subscribe('clever_sequence.sequence_not_found') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          events << event.payload
        end

        begin
          expect {
            described_class.nextval(klass, nonexistent_attribute, block, throw_if_sequence_not_found: true)
          }.to raise_error(CleverSequence::PostgresBackend::SequenceNotFoundError)

          expect(events.count).to eq 1
          payload = events.first
          expect(payload[:sequence_name]).to eq sequence_name
          expect(payload[:klass]).to eq klass
          expect(payload[:attribute]).to eq nonexistent_attribute
          expect(payload[:start_value]).to be_a(Integer)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
      end
    end

    context 'when throw_if_sequence_not_found is false' do
      it 'calculates a new sequence value' do
        result = described_class.nextval(klass, nonexistent_attribute, block, throw_if_sequence_not_found: false)
        expect(result).to eq 1
      end
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
