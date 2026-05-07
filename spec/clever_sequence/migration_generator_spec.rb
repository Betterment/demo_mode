# frozen_string_literal: true

require 'spec_helper'
require 'demo_mode/clever_sequence/migration_generator'

RSpec.describe CleverSequence::MigrationGenerator do
  let(:fake_klass) do
    Class.new do
      def self.name
        'FakeModel'
      end
    end
  end

  describe '#ci_output' do
    subject(:output) { described_class.new(sequence_data).ci_output }

    context 'with a single sequence' do
      let(:sequence_data) do
        [
          { sequence_name: 'cs_fake_models_email', klass: fake_klass, attribute: :email, calculated_start_value: 10 },
        ]
      end

      it 'generates migration instructions' do
        expected = <<~OUTPUT
          ===== Missing CleverSequence Sequences =====

          The following PostgreSQL sequences are required but do not exist:
            - cs_fake_models_email (FakeModel#email, start: 10)

          To create a migration, run:
            bundle exec rails generate migration <YourMigrationName>

          Then add the following to your migration:

          def up
            safety_assured do
                execute <<~SQL
                  CREATE SEQUENCE IF NOT EXISTS "cs_fake_models_email" START WITH 10;
                SQL
              end
          end

          def down
            safety_assured do
                execute <<~SQL
                  DROP SEQUENCE IF EXISTS "cs_fake_models_email";
                SQL
              end
          end
        OUTPUT

        expect(output).to eq expected
      end
    end

    context 'with multiple sequences that require ordering' do
      let(:sequence_data) do
        [
          { sequence_name: 'cs_zebra', klass: fake_klass, attribute: :name, calculated_start_value: 1 },
          { sequence_name: 'cs_apple', klass: fake_klass, attribute: :id, calculated_start_value: 100 },
        ]
      end

      it 'generates sorted migration instructions' do
        expected = <<~OUTPUT
          ===== Missing CleverSequence Sequences =====

          The following PostgreSQL sequences are required but do not exist:
            - cs_apple (FakeModel#id, start: 100)
            - cs_zebra (FakeModel#name, start: 1)

          To create a migration, run:
            bundle exec rails generate migration <YourMigrationName>

          Then add the following to your migration:

          def up
            safety_assured do
                execute <<~SQL
                  CREATE SEQUENCE IF NOT EXISTS "cs_apple" START WITH 100;
                  CREATE SEQUENCE IF NOT EXISTS "cs_zebra" START WITH 1;
                SQL
              end
          end

          def down
            safety_assured do
                execute <<~SQL
                  DROP SEQUENCE IF EXISTS "cs_apple";
                  DROP SEQUENCE IF EXISTS "cs_zebra";
                SQL
              end
          end
        OUTPUT

        expect(output).to eq expected
      end
    end
  end
end
