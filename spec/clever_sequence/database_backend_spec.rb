require 'spec_helper'

RSpec.describe CleverSequence::DatabaseBackend do
  let(:klass) { Widget }
  let(:attribute) { :integer_column }
  let(:block) { ->(i) { i } }

  before do
    skip 'DatabaseBackend requires PostgreSQL' unless ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  end

  context 'when sequence exists' do
    let(:sequence_name) { described_class.sequence_name(klass, attribute) }

    before do
      # Create the sequence manually
      ActiveRecord::Base.connection.execute(
        "CREATE SEQUENCE IF NOT EXISTS #{sequence_name} START WITH 1",
      )
    end

    after do
      # Clean up the sequence
      ActiveRecord::Base.connection.execute(
        "DROP SEQUENCE IF EXISTS #{sequence_name}",
      )
    end

    it 'returns the next value' do
      expect(described_class.nextval(klass, attribute, block)).to eq 1
      expect(described_class.nextval(klass, attribute, block)).to eq 2
      expect(described_class.nextval(klass, attribute, block)).to eq 3
    end

    it 'applies block transformation' do
      string_block = ->(i) { "User ##{i}" }
      expect(described_class.nextval(klass, attribute, string_block)).to eq 'User #1'
      expect(described_class.nextval(klass, attribute, string_block)).to eq 'User #2'
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
    end

    context 'when throw_if_sequence_not_found is true' do
      it 'throws a SequenceNotFoundError' do
        error = nil
        expect {
          described_class.nextval(klass, nonexistent_attribute, block, throw_if_sequence_not_found: true)
        }.to raise_error(CleverSequence::DatabaseBackend::SequenceNotFoundError) { |e| error = e }

        expect(error.sequence_name).to eq sequence_name
        expect(error.klass).to eq klass
        expect(error.attribute).to eq nonexistent_attribute
        expect(error.message).to include(sequence_name)
      end

      it 'raises SequenceNotFoundError by default' do
        expect {
          described_class.nextval(klass, nonexistent_attribute, block)
        }.to raise_error(CleverSequence::DatabaseBackend::SequenceNotFoundError)
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
      expect(name).to eq 'clever_seq_widgets_email'
    end

    it 'sanitizes special characters' do
      allow(klass).to receive(:table_name).and_return('my-table$name')
      name = described_class.sequence_name(klass, :'my-attr$name')
      expect(name).to eq 'clever_seq_my_table_name_my_attr_name'
    end

    it 'truncates to 63 characters' do
      allow(klass).to receive(:table_name).and_return('a' * 50)
      name = described_class.sequence_name(klass, 'b' * 50)
      expect(name.length).to eq 63
      expect(name).to start_with('clever_seq_')
    end
  end
end