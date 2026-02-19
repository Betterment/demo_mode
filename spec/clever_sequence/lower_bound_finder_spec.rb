# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleverSequence::LowerBoundFinder do
  let(:klass) { Widget }
  let(:finder) { described_class.new(klass, :integer_column, ->(i) { i }) }

  around do |example|
    klass.delete_all
    CleverSequence.reset!
    example.run
    CleverSequence.reset!
  end

  describe '#lower_bound' do
    it 'returns 0 when no records exist' do
      allow(klass).to receive(:find_by_integer_column).and_return(nil)

      expect(finder.lower_bound).to eq 0
    end

    it 'returns 1 when only record 1 exists' do
      allow(klass).to receive(:find_by_integer_column).and_return(nil)
      allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)

      expect(finder.lower_bound).to eq 1
    end

    it 'returns 2 when records 1 and 2 exist' do
      allow(klass).to receive(:find_by_integer_column).and_return(nil)
      allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)
      allow(klass).to receive(:find_by_integer_column).with(2).and_return(true)

      expect(finder.lower_bound).to eq 2
    end

    it 'handles many consecutive records efficiently via binary search' do
      existing_records = (1..100).to_a
      allow(klass).to receive(:find_by_integer_column) do |val|
        existing_records.include?(val)
      end

      expect(finder.lower_bound).to eq 100

      # Verify it used binary search (should be O(log n) calls, not 100)
      expect(klass).to have_received(:find_by_integer_column).at_most(20).times
    end

    it 'finds consecutive records and returns highest existing value' do
      allow(klass).to receive(:find_by_integer_column).and_return(nil)
      allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)
      allow(klass).to receive(:find_by_integer_column).with(2).and_return(true)
      # Gap at 3 - the finder will find 2 as the lower bound
      # because it searches for consecutive records starting from 1
      allow(klass).to receive(:find_by_integer_column).with(3).and_return(nil)

      expect(finder.lower_bound).to eq 2
    end

    it 'handles large existing record counts efficiently' do
      # Simulate 1000 consecutive records existing
      allow(klass).to receive(:find_by_integer_column) do |val|
        val <= 1000
      end

      expect(finder.lower_bound).to eq 1000

      # Binary search should find this in O(log n) queries, not 1000
      expect(klass).to have_received(:find_by_integer_column).at_most(25).times
    end
  end

  describe '#next_between' do
    it 'calculates next search point using formula [((lower+1)/2)+(upper/2), lower*2].min' do
      # For lower=10, upper=100: min((5 + 50), 20) = 20
      result = finder.send(:next_between, 10, 100)
      expect(result).to eq 20
    end

    it 'handles infinite upper bound by capping at lower * 2' do
      result = finder.send(:next_between, 1, Float::INFINITY)
      expect(result).to eq 2
    end

    it 'doubles lower value for large upper bounds' do
      result = finder.send(:next_between, 10, Float::INFINITY)
      expect(result).to eq 20
    end

    it 'returns 0 when lower is 0' do
      # This is by design - when starting fresh, first check is at 1
      result = finder.send(:next_between, 0, Float::INFINITY)
      expect(result).to eq 0
    end
  end

  describe '#exists?' do
    it 'applies the block transformation before checking' do
      finder = described_class.new(klass, :string_column, ->(i) { "item_#{i}" })
      allow(klass).to receive(:find_by_string_column).and_return(nil)
      allow(klass).to receive(:find_by_string_column).with('item_5').and_return(true)

      expect(finder.send(:exists?, 5)).to be_truthy
      expect(finder.send(:exists?, 6)).to be_falsey
    end
  end

  describe '#finder_method' do
    it 'generates correct finder method for regular columns' do
      finder = described_class.new(klass, :integer_column, ->(i) { i })
      expect(finder.send(:finder_method)).to eq :find_by_integer_column
    end

    it 'strips _crypt suffix for encrypted columns' do
      finder = described_class.new(klass, :encrypted_column_crypt, ->(i) { i })
      expect(finder.send(:finder_method)).to eq :find_by_encrypted_column
    end

    it 'handles underscored column names' do
      finder = described_class.new(klass, :some_long_column_name, ->(i) { i })
      expect(finder.send(:finder_method)).to eq :find_by_some_long_column_name
    end
  end
end
