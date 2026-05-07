# frozen_string_literal: true

# rubocop:disable Rails/Output

require 'demo_mode/cli'

namespace :persona do
  desc 'Pick a persona and generate an account'
  task create: :environment do
    DemoMode::Cli.start
  end
end

namespace :clever_sequence do
  desc 'Discover all required PostgreSQL sequences for CleverSequence PostgresBackend'
  task discover: :environment do
    require 'demo_mode/clever_sequence/migration_generator'

    missing = CleverSequence::MigrationGenerator.discover_missing

    if missing.any?
      puts CleverSequence::MigrationGenerator.new(missing).ci_output
    else
      puts 'All sequences exist! No migration needed.'
    end
  end
end

# rubocop:enable Rails/Output
