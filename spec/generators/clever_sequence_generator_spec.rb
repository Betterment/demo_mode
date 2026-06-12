# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'rails/generators'
require 'generators/demo_mode/clever_sequence_generator'

RSpec.describe DemoMode::CleverSequenceGenerator do
  around do |example|
    Dir.mktmpdir do |dir|
      @destination_root = dir
      example.run
    end
  end

  def run_generator(args)
    described_class.start(args, destination_root: @destination_root)
  end

  def generated_migration
    path = Dir[File.join(@destination_root, 'db/migrate/*.rb')].sole
    [File.basename(path), File.read(path)]
  end

  it 'creates a timestamped migration that creates the sequence' do
    run_generator(%w[Widget integer_column])

    filename, contents = generated_migration

    expect(filename).to match(/\A\d{14}_create_clever_sequence_cs_widgets_integer_column\.rb\z/)
    expect(contents).to include('class CreateCleverSequenceCsWidgetsIntegerColumn < ActiveRecord::Migration')
    expect(contents).to include('CREATE SEQUENCE IF NOT EXISTS cs_widgets_integer_column')
    expect(contents).to include('DROP SEQUENCE IF EXISTS cs_widgets_integer_column')
  end

  it 'seeds the sequence past existing data using the backing column' do
    run_generator(%w[Widget integer_column])

    _filename, contents = generated_migration

    expect(contents).to include('SELECT COALESCE(MAX(integer_column), 0) FROM widgets')
    expect(contents).to include("execute(\"SELECT setval('cs_widgets_integer_column', \#{max_value})\") if max_value >= 1")
  end

  it 'names the sequence from the attribute but reads MAX from the aliased column' do
    run_generator(%w[Widget integer_aliased])

    _filename, contents = generated_migration

    # Sequence name tracks the attribute as referenced by CleverSequence...
    expect(contents).to include('CREATE SEQUENCE IF NOT EXISTS cs_widgets_integer_aliased')
    # ...while the MAX query resolves the alias to the real DB column.
    expect(contents).to include('SELECT COALESCE(MAX(integer_column), 0) FROM widgets')
  end

  it 'writes to an explicit --migrations-path (e.g. an adjacent engine in a monorepo)' do
    run_generator(%w[Widget integer_column --migrations-path ../engine/db/migrate])

    expect(Dir[File.join(@destination_root, 'db/migrate/*.rb')]).to be_empty
    written = Dir[File.join(@destination_root, '../engine/db/migrate/*.rb')]
    expect(written.sole).to match(/create_clever_sequence_cs_widgets_integer_column\.rb\z/)
  end
end
