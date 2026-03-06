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

  describe '.use_database_sequences?' do
    after do
      described_class.use_database_sequences = false
    end

    it 'returns false by default' do
      expect(described_class.use_database_sequences?).to be(false)
    end

    context 'when enabled' do
      before do
        described_class.use_database_sequences = true
      end

      it 'returns true' do
        expect(described_class.use_database_sequences?).to be(true)
      end
    end
  end

  describe '.enforce_sequences_exist?' do
    after do
      described_class.enforce_sequences_exist = false
    end

    it 'returns false by default' do
      expect(described_class.enforce_sequences_exist?).to be(false)
    end

    context 'when enabled' do
      before do
        described_class.enforce_sequences_exist = true
      end

      it 'returns true' do
        expect(described_class.enforce_sequences_exist?).to be(true)
      end
    end
  end

  describe '.backend' do
    after do
      described_class.use_database_sequences = false
    end

    it 'returns InMemoryBackend by default' do
      expect(described_class.backend).to eq CleverSequence::InMemoryBackend
    end

    context 'when use_database_sequences is true' do
      before { described_class.use_database_sequences = true }

      it 'returns PostgresBackend' do
        expect(described_class.backend).to eq CleverSequence::PostgresBackend
      end
    end
  end

  describe '.reset!' do
    let(:attribute) { :integer_column }

    it 'delegates to the active backend' do
      expect(described_class.backend).to receive(:reset!)
      described_class.reset!
    end

    it 'clears instance-level state so sequences re-derive from the backend' do
      allow(described_class.backend).to receive(:nextval).and_return(1, 2)

      expect(subject.next).to eq 1

      described_class.reset!

      expect(subject.next).to eq 2
    end
  end

  describe '.next' do
    it 'delegates to the backend and returns sequential values' do
      allow(described_class.backend).to receive(:nextval).and_return(1, 2, 3)
      expect(described_class.next(klass, :some_column)).to eq 1
      expect(described_class.next(klass, :some_column)).to eq 2
      expect(described_class.next(klass, :some_column)).to eq 3
    end
  end

  describe '.last' do
    let(:attribute) { :integer_column }

    it 'returns the last generated value' do
      allow(described_class.backend).to receive(:nextval).and_return(10, 11)
      described_class.next(klass, :integer_column)
      described_class.next(klass, :integer_column)

      expect(described_class.last(klass, :integer_column)).to eq 11
    end

    it 'returns the starting value from the backend when no values have been generated' do
      allow(described_class.backend).to receive(:starting_value).and_return(5)
      expect(described_class.last(klass, :nonexistent_attribute)).to eq 5
    end
  end

  describe '#next' do
    let(:attribute) { :integer_column }

    it 'delegates to the backend' do
      allow(described_class.backend).to receive(:nextval).and_return(42)
      expect(subject.next).to eq 42
    end

    it 'returns sequential values from the backend' do
      allow(described_class.backend).to receive(:nextval).and_return(1, 2, 3)
      expect(subject.next).to eq 1
      expect(subject.next).to eq 2
      expect(subject.next).to eq 3
    end

    context 'with a block transformation' do
      let(:attribute) { :string_column }
      let(:block) { ->(i) { "klass ##{i}" } }

      it 'applies the block to the backend value' do
        allow(described_class.backend).to receive(:nextval).and_return(1, 2)
        expect(subject.next).to eq 'klass #1'
        expect(subject.next).to eq 'klass #2'
      end
    end

    context 'with a date block transformation' do
      let(:attribute) { :date_column }
      let(:block) { ->(i) { Date.parse('2016-05-15') + i.days } }

      it 'applies the block to the backend value' do
        allow(described_class.backend).to receive(:nextval).and_return(1, 2)
        expect(subject.next).to eq '2016-05-16'.to_date
        expect(subject.next).to eq '2016-05-17'.to_date
      end
    end
  end

  describe '#last' do
    let(:attribute) { :integer_column }

    it 'returns the current value without incrementing' do
      allow(described_class.backend).to receive(:nextval).and_return(5)
      subject.next
      expect(subject.last).to eq 5
      expect(subject.last).to eq 5
      expect(subject.last).to eq 5
    end

    it 'applies the block transformation' do
      seq = described_class.new(:string_column) { |i| "value_#{i}" }.with_class(klass)
      allow(described_class.backend).to receive(:nextval).and_return(7, 8)
      seq.next
      seq.next

      expect(seq.last).to eq 'value_8'
    end
  end

  describe 'FactoryBot integration' do
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

  describe 'configuration within DemoMode.configure' do
    after do
      described_class.use_database_sequences = false
      described_class.enforce_sequences_exist = false
    end

    it 'allows setting use_database_sequences within DemoMode.configure block' do
      klass = described_class
      DemoMode.configure do
        klass.use_database_sequences = true
      end

      expect(described_class.use_database_sequences?).to be(true)
    end

    it 'allows setting enforce_sequences_exist within DemoMode.configure block' do
      klass = described_class
      DemoMode.configure do
        klass.enforce_sequences_exist = true
      end

      expect(described_class.enforce_sequences_exist?).to be(true)
    end
  end
end
