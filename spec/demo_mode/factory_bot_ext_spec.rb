# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoMode::FactoryBotExt do
  before do
    stub_const('User', Struct.new(:name))
  end

  after do
    FactoryBot.remove_instance_variable(:@around_each) if FactoryBot.instance_variable_defined?(:@around_each)
    FactoryBot.factories.clear
  end

  let!(:factory) do
    FactoryBot.define do
      factory :user do
        name { 'Test User' }
      end
    end
  end

  it 'does not interfere if no custom around_each is set' do
    user = nil
    expect { user = FactoryBot.build(:user) }.not_to raise_error
    expect(user.name).to eq('Test User')
  end

  context 'when an around_each is set' do
    let(:events) { [] }

    before do
      FactoryBot.around_each do |&blk|
        events << :before
        result = blk.call
        result.tap { events << :after }
      ensure
        events << :ensure
      end
    end

    it 'calls the around_each block when building a factory' do
      user = FactoryBot.build(:user)

      expect(events).to eq(%i(before after ensure))
      expect(user.name).to eq('Test User')
    end

    context 'when the factory raises an error' do
      let!(:factory) do
        FactoryBot.define do
          factory :user do
            name { raise 'Intentional Error' }
          end
        end
      end

      it 'calls the ensure block' do
        expect { FactoryBot.build(:user) }.to raise_error('Intentional Error')

        expect(events).to eq(%i(before ensure))
      end
    end

    context 'and a second around_each hooks is defined' do
      before do
        FactoryBot.around_each do |&blk|
          events << :before_second
          result = blk.call
          result.tap { events << :after_second }
        ensure
          events << :ensure_second
        end
      end

      it 'calls all around_each hooks in order' do
        user = FactoryBot.build(:user)

        expect(events).to eq(%i(before before_second after_second ensure_second after ensure))
        expect(user.name).to eq('Test User')
      end
    end
  end
end
