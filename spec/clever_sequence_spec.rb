# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleverSequence do
  let(:block) { nil }
  let(:klass) { Widget }

  subject { described_class.new(attribute, &block).with_class(klass) }

  delegate :create, :build, :attributes_for, to: FactoryBot

  around do |example|
    klass.delete_all
    described_class.reset!
    example.run
    described_class.reset!
  end

  describe 'Factory Bot Patch' do
    before do
      next if FactoryBot.factories.registered?(:widget)

      FactoryBot.define do
        factory :widget do
          sequence(:integer_column)
          sequence(:string_column)
          sequence(:text_column) { |i| "Foo ##{i}" }
          sequence(:encrypted_column_crypt) { |i| "Bar #{i + 10}" }
        end
      end
    end

    it 'sets up the sequence for declared columns' do
      create(:widget).tap do |widget|
        expect(widget.integer_column).to eq 1
        expect(widget.string_column).to eq '1'
        expect(widget.text_column).to eq 'Foo #1'
        expect(widget.encrypted_column_crypt).to eq 'Bar 11'
      end
      create(:widget).tap do |widget|
        expect(widget.integer_column).to eq 2
        expect(widget.string_column).to eq '2'
        expect(widget.text_column).to eq 'Foo #2'
        expect(widget.encrypted_column_crypt).to eq 'Bar 12'
      end
      described_class.reset!
      build(:widget).tap do |widget|
        expect(widget.integer_column).to eq 3
        expect(widget.string_column).to eq '3'
        expect(widget.text_column).to eq 'Foo #3'
        expect(widget.encrypted_column_crypt).to eq 'Bar 13'
      end

      expect(described_class.last(Widget, :integer_column)).to eq 3
      expect(described_class.last(Widget, :string_column)).to eq 3
      expect(described_class.last(Widget, :text_column)).to eq 'Foo #3'
      expect(described_class.last(Widget, :encrypted_column_crypt)).to eq 'Bar 13'

      expect(described_class.next(Widget, :integer_column)).to eq 4
      expect(described_class.next(Widget, :string_column)).to eq 4
      expect(described_class.next(Widget, :text_column)).to eq 'Foo #4'
      expect(described_class.next(Widget, :encrypted_column_crypt)).to eq 'Bar 14'
    end

    it 'works with attributes_for' do
      attributes_for(:widget).tap do |attributes|
        expect(attributes[:integer_column]).to eq 1
        expect(attributes[:string_column]).to eq 1
        expect(attributes[:text_column]).to eq 'Foo #1'
        expect(attributes[:encrypted_column_crypt]).to eq 'Bar 11'
      end
      attributes_for(:widget).tap do |attributes|
        expect(attributes[:integer_column]).to eq 2
        expect(attributes[:string_column]).to eq 2
        expect(attributes[:text_column]).to eq 'Foo #2'
        expect(attributes[:encrypted_column_crypt]).to eq 'Bar 12'
      end

      expect(described_class.last(Widget, :integer_column)).to eq 2
      expect(described_class.last(Widget, :string_column)).to eq 2
      expect(described_class.last(Widget, :text_column)).to eq 'Foo #2'
      expect(described_class.last(Widget, :encrypted_column_crypt)).to eq 'Bar 12'

      expect(described_class.next(Widget, :integer_column)).to eq 3
      expect(described_class.next(Widget, :string_column)).to eq 3
      expect(described_class.next(Widget, :text_column)).to eq 'Foo #3'
      expect(described_class.next(Widget, :encrypted_column_crypt)).to eq 'Bar 13'
    end
  end

  describe '.next' do
    context 'for an integer column' do
      let(:attribute) { :integer_column }

      it 'starts at 1 and keeps going without queries' do
        expect(klass).to receive(:find_by_integer_column).with(1).and_call_original
        expect(subject.next).to eq 1
        expect(klass).not_to receive(:find_by_integer_column)
        expect(subject.next).to eq 2
      end

      context 'when a record exists' do
        it 'starts at the next value' do
          allow(klass).to receive(:find_by_integer_column).and_return(nil)
          allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)
          expect(subject.next).to eq 2
          expect(klass).to have_received(:find_by_integer_column).with(1)
          expect(klass).not_to receive(:find_by_integer_column)
          expect(subject.next).to eq 3
        end
      end

      context 'when it is aliased' do
        let(:attribute) { :integer_aliased }

        it 'starts at 1 and keeps going without queries' do
          expect(klass).to receive(:find_by_integer_column).with(1).and_call_original
          expect(subject.next).to eq 1
        end
      end
    end

    context 'for a string column' do
      let(:attribute) { :string_column }
      let(:block) { ->(i) { "klass ##{i}" } }

      it 'starts at 1 and keeps going without queries' do
        expect(klass).to receive(:find_by_string_column).and_call_original
        expect(subject.next).to eq 'klass #1'
        expect(klass).not_to receive(:find_by_string_column)
        expect(subject.next).to eq 'klass #2'
      end

      context 'when a record exists' do
        let!(:existing_klass) { klass.create!(string_column: 'klass #34244') }

        it 'starts at 1 and keeps going without queries' do
          expect(klass).to receive(:find_by_string_column).with('klass #1').and_call_original
          expect(subject.next).to eq 'klass #1'
          expect(klass).not_to receive(:find_by_string_column)
          expect(subject.next).to eq 'klass #2'
        end
      end

      context 'when a record without a number exists' do
        let!(:existing_klass) { klass.create!(string_column: 'Some klass') }

        it 'starts at 1' do
          expect(klass).to receive(:find_by_string_column).and_call_original
          expect(subject.next).to eq 'klass #1'
        end
      end

      context 'when it is aliased' do
        let(:attribute) { :name_aliased }

        it 'starts at 1 and keeps going without queries' do
          expect(klass).to receive(:find_by_string_column).and_call_original
          expect(subject.next).to eq 'klass #1'
        end
      end
    end

    context 'for an encrypted column' do
      let(:attribute) { :encrypted_column_crypt }
      let(:block) { ->(i) { "TEST#{i}TEST" } }

      it 'uses the lower bound finder to find the next from the database' do
        allow(klass).to receive(:find_by_encrypted_column).and_return(nil)
        allow(klass).to receive(:find_by_encrypted_column).with('TEST1TEST').and_return(true)
        expect(subject.next).to eq 'TEST2TEST'
        expect(klass).to have_received(:find_by_encrypted_column).with('TEST1TEST')
        expect(klass).not_to receive(:find_by_encrypted_column)
        expect(subject.next).to eq 'TEST3TEST'
      end

      context 'when it is also aliased' do
        let(:attribute) { :encrypted_column }

        it 'uses the lower bound finder to find the next from the database' do
          allow(klass).to receive(:find_by_encrypted_column).and_return(nil)
          allow(klass).to receive(:find_by_encrypted_column).with('TEST1TEST').and_return(true)
          expect(subject.next).to eq 'TEST2TEST'
          expect(klass).to have_received(:find_by_encrypted_column).with('TEST1TEST')
          expect(klass).not_to receive(:find_by_encrypted_column)
          expect(subject.next).to eq 'TEST3TEST'
        end
      end
    end

    context 'for a non-roundtrippable string sequence' do
      let(:attribute) { :text_column }
      let(:block) { ->(i) { "234-22-#{i.to_s.rjust(2, '9')}" } }

      it 'uses the lower bound finder and starts at zero' do
        expect(klass).to receive(:find_by_text_column).and_call_original
        expect(subject.next).to eq '234-22-91'
        expect(klass).not_to receive(:find_by_text_column)
        expect(subject.next).to eq '234-22-92'
      end

      context 'when the first couple attributes exist' do
        it 'uses the lower bound finder to find the next from the database' do
          allow(klass).to receive(:find_by_text_column).and_return(nil)
          allow(klass).to receive(:find_by_text_column).with('234-22-91').and_return(true)
          allow(klass).to receive(:find_by_text_column).with('234-22-92').and_return(true)
          expect(subject.next).to eq '234-22-93'
          expect(klass).to have_received(:find_by_text_column).with('234-22-91')
          expect(klass).to have_received(:find_by_text_column).with('234-22-92')
          expect(klass).not_to receive(:find_by_text_column)
          expect(subject.next).to eq '234-22-94'
        end
      end
    end

    context 'for a date column' do
      let(:attribute) { :date_column }
      let(:block) { ->(i) { Date.parse('2016-05-15') + i.days } }

      it 'starts the sequence with a query' do
        expect(klass).to receive(:find_by_date_column).with('2016-05-16'.to_date).and_call_original
        expect(subject.next).to eq '2016-05-16'.to_date
        expect(klass).not_to receive(:find_by_date_column)
        expect(subject.next).to eq '2016-05-17'.to_date
      end
    end

    context "for a column that doesn't exist" do
      let(:attribute) { :banana }

      it 'starts the sequence but without a database query' do
        expect(klass).not_to receive(:"find_by_#{attribute}")
        expect(subject.next).to eq 1
        expect(subject.next).to eq 2
      end
    end
  end

  describe '.reset!' do
    let(:attribute) { :integer_column }

    it 'clears @last_value and restarts sequence from database state' do
      subject.next
      subject.next
      expect(subject.last).to eq 2

      described_class.reset!

      expect(subject.instance_variable_defined?(:@last_value)).to be false
    end

    it 'allows sequence to restart fresh and re-query database' do
      expect(subject.next).to eq 1

      described_class.reset!

      # After reset, sequence will re-query the database
      # and find that value 1 exists
      expect(klass).to receive(:find_by_integer_column).with(1).and_return(true)
      expect(klass).to receive(:find_by_integer_column).with(2).and_return(nil)

      expect(subject.next).to eq 2
    end

    it 'works when no sequences have been registered' do
      described_class.sequences.clear
      expect { described_class.reset! }.not_to raise_error
    end

    it 'resets all registered sequences' do
      seq1 = described_class.new(:integer_column).with_class(klass)
      seq2 = described_class.new(:text_column) { |i| "text_#{i}" }.with_class(klass)

      seq1.next
      seq2.next
      seq2.next

      expect(seq1.last).to eq 1
      expect(seq2.last).to eq 'text_2'

      described_class.reset!

      expect(seq1.instance_variable_defined?(:@last_value)).to be false
      expect(seq2.instance_variable_defined?(:@last_value)).to be false
    end
  end

  describe '#last' do
    let(:attribute) { :integer_column }

    it 'returns the current value without incrementing' do
      subject.next
      expect(subject.last).to eq 1
      expect(subject.last).to eq 1
      expect(subject.last).to eq 1
    end

    it 'applies the block transformation' do
      seq = described_class.new(:string_column) { |i| "value_#{i}" }.with_class(klass)
      seq.next
      seq.next

      expect(seq.last).to eq 'value_2'
    end

    context 'before any calls to next' do
      it 'returns the starting value' do
        expect(klass).to receive(:find_by_integer_column).with(1).and_return(nil)
        expect(subject.last).to eq 0
      end
    end
  end

  describe '.last (class method)' do
    let(:attribute) { :integer_column }

    it 'returns the last value for a registered sequence' do
      subject.next
      subject.next

      expect(described_class.last(klass, :integer_column)).to eq 2
    end

    it 'creates a new sequence if one does not exist and returns starting value' do
      # The lookup method creates a sequence if it doesn't exist
      # For a non-existent column, it defaults to starting value of 0
      result = described_class.last(klass, :nonexistent_attribute)
      expect(result).to eq 0
    end

    it 'creates and returns a sequence when looking up a new attribute' do
      # date_column doesn't have a factory sequence defined, so it uses DEFAULT_BLOCK
      result = described_class.next(klass, :date_column)

      expect(result).to eq 1
      expect(described_class.last(klass, :date_column)).to eq 1
    end
  end

  describe '.next (class method)' do
    it 'creates a sequence if it does not exist' do
      expect(described_class.sequences).not_to have_key([klass.name, 'new_column'])

      result = described_class.next(klass, :new_column)

      expect(result).to eq 1
      expect(described_class.sequences).to have_key([klass.name, 'new_column'])
    end

    it 'reuses existing sequence' do
      described_class.next(klass, :integer_column)
      described_class.next(klass, :integer_column)

      expect(described_class.next(klass, :integer_column)).to eq 3
    end
  end

  describe '#with_class' do
    let(:attribute) { :integer_column }

    it 'returns self for chaining' do
      seq = described_class.new(attribute)
      expect(seq.with_class(klass)).to eq seq
    end

    it 'registers the sequence in the class sequences hash' do
      seq = described_class.new(attribute)
      seq.with_class(klass)

      expect(described_class.sequences[[klass.name, attribute.to_s]]).to eq seq
    end

    it 'does not overwrite klass when called again' do
      seq = described_class.new(attribute)
      seq.with_class(klass)

      other_klass = Class.new(ActiveRecord::Base)
      stub_const('OtherWidget', other_klass)

      seq.with_class(other_klass)
      expect(seq.klass).to eq klass
    end

    it 'does not register when klass is nil' do
      seq = described_class.new(attribute)
      seq.with_class(nil)

      expect(described_class.sequences[[nil, attribute.to_s]]).to be_nil
    end
  end

  describe 'LowerBoundFinder' do
    let(:finder) { CleverSequence::LowerBoundFinder.new(klass, :integer_column, ->(i) { i }) }

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

      it 'handles large starting record numbers' do
        allow(klass).to receive(:find_by_integer_column).and_return(nil)
        allow(klass).to receive(:find_by_integer_column).with(1).and_return(true)
        allow(klass).to receive(:find_by_integer_column).with(2).and_return(true)
        allow(klass).to receive(:find_by_integer_column).with(3).and_return(true)

        expect(finder.lower_bound).to eq 3
      end
    end

    describe '#finder_method' do
      it 'generates correct finder method for regular columns' do
        finder = CleverSequence::LowerBoundFinder.new(klass, :integer_column, ->(i) { i })
        expect(finder.send(:finder_method)).to eq :find_by_integer_column
      end

      it 'strips _crypt suffix for encrypted columns' do
        finder = CleverSequence::LowerBoundFinder.new(klass, :encrypted_column_crypt, ->(i) { i })
        expect(finder.send(:finder_method)).to eq :find_by_encrypted_column
      end

      it 'handles underscored column names' do
        finder = CleverSequence::LowerBoundFinder.new(klass, :some_long_column_name, ->(i) { i })
        expect(finder.send(:finder_method)).to eq :find_by_some_long_column_name
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
        finder = CleverSequence::LowerBoundFinder.new(klass, :string_column, ->(i) { "item_#{i}" })
        allow(klass).to receive(:find_by_string_column).and_return(nil)
        allow(klass).to receive(:find_by_string_column).with('item_5').and_return(true)

        expect(finder.send(:exists?, 5)).to be_truthy
        expect(finder.send(:exists?, 6)).to be_falsey
      end
    end
  end

  describe 'DEFAULT_BLOCK' do
    it 'returns the input unchanged' do
      expect(CleverSequence::DEFAULT_BLOCK.call(1)).to eq 1
      expect(CleverSequence::DEFAULT_BLOCK.call(42)).to eq 42
    end
  end

  describe '#initialize' do
    it 'converts attribute to string' do
      seq = described_class.new(:my_attr)
      expect(seq.attribute).to eq 'my_attr'
    end

    it 'uses DEFAULT_BLOCK when no block is provided' do
      seq = described_class.new(:my_attr)
      expect(seq.block).to eq CleverSequence::DEFAULT_BLOCK
    end

    it 'uses provided block' do
      custom_block = ->(i) { i * 2 }
      seq = described_class.new(:my_attr, &custom_block)
      expect(seq.block).to eq custom_block
    end
  end
end
