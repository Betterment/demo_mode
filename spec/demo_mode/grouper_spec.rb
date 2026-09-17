# frozen_string_literal: true

require 'spec_helper'
require 'demo_mode/grouper'

RSpec.describe DemoMode::Grouper do
  def grouper(personas, groups: [])
    described_class.new(personas, groups: groups)
  end

  def fake_persona(name, group)
    Struct.new(:name, :group).new(name, group)
  end

  describe '#named' do
    it 'buckets personas by group name, excluding ungrouped personas' do
      first_playwright = fake_persona('first_playwright', 'Playwright tests')
      second_playwright = fake_persona('second_playwright', 'Playwright tests')
      plain_persona = fake_persona('plain_persona', nil)

      named = grouper([first_playwright, second_playwright, plain_persona]).named

      expect(named.to_h).to eq('Playwright tests' => [first_playwright, second_playwright])
    end

    it 'defaults to alphabetical order when no groups config is set' do
      zebra = fake_persona('z_persona', 'zebra')
      aardvark = fake_persona('a_persona', 'aardvark')

      named = grouper([zebra, aardvark]).named

      expect(named.map(&:first)).to eq %w(aardvark zebra)
    end

    it 'orders named groups per the groups config, with unlisted groups falling back to alphabetical' do
      aardvark = fake_persona('a_persona', 'aardvark')
      zebra = fake_persona('z_persona', 'zebra')
      middle = fake_persona('m_persona', 'middle')

      named = grouper([aardvark, zebra, middle], groups: %w(zebra aardvark)).named

      expect(named.map(&:first)).to eq %w(zebra aardvark middle)
    end

    it 'orders named groups per a groups hash, keyed by the raw group name' do
      aardvark = fake_persona('a_persona', 'aardvark')
      zebra = fake_persona('z_persona', 'zebra')

      named = grouper([aardvark, zebra], groups: { 'zebra' => 'The Zebras' }).named

      expect(named.map(&:first)).to eq %w(zebra aardvark)
    end
  end

  describe '#named_groups' do
    it 'pairs each group with its resolved name and personas, in order' do
      aardvark = fake_persona('a_persona', 'aardvark')
      zebra = fake_persona('z_persona', 'zebra')

      named_groups = grouper([aardvark, zebra], groups: { 'zebra' => 'The Zebras' }).named_groups

      expect(named_groups).to eq [
        ['The Zebras', [zebra]],
        ['aardvark', [aardvark]],
      ]
    end
  end

  describe '#ungrouped' do
    it 'returns personas with no group' do
      plain_persona = fake_persona('plain_persona', nil)
      grouped_persona = fake_persona('grouped_persona', 'Playwright tests')

      expect(grouper([plain_persona, grouped_persona]).ungrouped).to eq [plain_persona]
    end

    it 'returns an empty array when every persona is grouped' do
      grouped_persona = fake_persona('grouped_persona', 'Playwright tests')

      expect(grouper([grouped_persona]).ungrouped).to eq []
    end
  end

  describe '#name_for' do
    it 'defaults to the raw group key when groups is an array' do
      expect(grouper([], groups: %w(retail)).name_for('retail')).to eq 'retail'
    end

    it 'uses the configured label when groups is a hash' do
      expect(grouper([], groups: { 'retail' => 'Retail Banking' }).name_for('retail')).to eq 'Retail Banking'
    end

    it 'falls back to the raw key for groups not present in the hash' do
      expect(grouper([], groups: { 'retail' => 'Retail Banking' }).name_for('wealth')).to eq 'wealth'
    end
  end
end
