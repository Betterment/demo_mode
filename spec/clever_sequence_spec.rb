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

  describe 'configuration within DemoMode.configure' do
    after do
      described_class.use_database_sequences = false
      described_class.enforce_sequences_exist = false
    end

    it 'allows setting use_database_sequences within DemoMode.configure block' do
      DemoMode.configure do
        CleverSequence.use_database_sequences = true
      end

      expect(described_class.use_database_sequences?).to be(true)
    end

    it 'allows setting enforce_sequences_exist within DemoMode.configure block' do
      DemoMode.configure do
        CleverSequence.enforce_sequences_exist = true
      end

      expect(described_class.enforce_sequences_exist?).to be(true)
    end
  end
end
