# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleverSequence::InMemoryBackend do
  let(:klass) { Widget }
  let(:block) { CleverSequence::DEFAULT_BLOCK }

  before { described_class.reset! }
  after { described_class.reset! }

  describe '.nextval' do
    context 'for an integer column' do
      it 'starts at 1 when no records exist' do
        expect(described_class.nextval(klass, :integer_column, block)).to eq 1
      end

      it 'increments on each call' do
        expect(described_class.nextval(klass, :integer_column, block)).to eq 1
        expect(described_class.nextval(klass, :integer_column, block)).to eq 2
        expect(described_class.nextval(klass, :integer_column, block)).to eq 3
      end

      it 'only queries the database on the first call' do
        expect(klass).to receive(:find_by_integer_column).with(1).and_call_original
        described_class.nextval(klass, :integer_column, block)

        expect(klass).not_to receive(:find_by_integer_column)
        described_class.nextval(klass, :integer_column, block)
      end

      context 'when a record exists' do
        it 'starts after the existing record' do
          allow(klass).to receive(:find_by_integer_column).and_return(nil)
          allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)

          expect(described_class.nextval(klass, :integer_column, block)).to eq 2
        end
      end
    end

    context 'for an aliased column' do
      it 'resolves the alias and queries the correct column' do
        expect(klass).to receive(:find_by_integer_column).with(1).and_call_original
        expect(described_class.nextval(klass, :integer_aliased, block)).to eq 1
      end
    end

    context 'for an encrypted column' do
      let(:block) { ->(i) { "TEST#{i}TEST" } }

      it 'uses the block when checking for existing records' do
        allow(klass).to receive(:find_by_encrypted_column).and_return(nil)
        allow(klass).to receive(:find_by_encrypted_column).with('TEST1TEST').and_return(true)

        expect(described_class.nextval(klass, :encrypted_column_crypt, block)).to eq 2
      end
    end

    context 'for a nonexistent column' do
      it 'starts at 1' do
        expect(described_class.nextval(klass, :nonexistent, block)).to eq 1
      end

      it 'increments on each call' do
        expect(described_class.nextval(klass, :nonexistent, block)).to eq 1
        expect(described_class.nextval(klass, :nonexistent, block)).to eq 2
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

    it 'resolves aliased attributes' do
      allow(klass).to receive(:find_by_integer_column).with(1).and_call_original
      expect(described_class.starting_value(klass, :integer_aliased, block)).to eq 0
    end
  end

  describe '.reset!' do
    it 'clears all sequence state so values re-derive from the database' do
      described_class.nextval(klass, :integer_column, block)
      described_class.nextval(klass, :integer_column, block)

      described_class.reset!

      allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)
      allow(klass).to receive(:find_by_integer_column).with(2).and_return(nil)

      expect(described_class.nextval(klass, :integer_column, block)).to eq 2
    end
  end
end
