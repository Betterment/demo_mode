# frozen_string_literal: true

require_relative 'postgres_backend'

# rubocop:disable Rails/Output
class CleverSequence
  class MigrationGenerator
    class << self
      def discover_missing
        raise 'CleverSequence sequence discovery can only be run in development' unless Rails.env.development?

        puts 'Discovering required CleverSequence sequences...'
        puts "Found #{DemoMode.personas.count} personas to process"

        # Enable database sequences mode so we can discover all required sequences
        CleverSequence.use_database_sequences = true
        # Disable retries so RecordNotUnique/RecordInvalid errors propagate instead of
        # triggering with_sequence_adjustment which would reset the sequence cache and
        # lose discovered Missing entries
        CleverSequence.retry_on_uniqueness_violation = false

        missing_sequences = harvest_missing_sequences
        puts "\n"
        missing_sequences.values.map(&:to_h)
      ensure
        CleverSequence.use_database_sequences = false
        CleverSequence.enforce_sequences_exist = false
        CleverSequence.retry_on_uniqueness_violation = true
      end

      private

      # Persona#generate! calls CleverSequence.reset! at the start of every persona,
      # which wipes Thread.current[:clever_sequence_cache]. Harvest after each
      # persona so Missing entries from earlier personas aren't lost. When the same
      # sequence is missed by multiple personas, keep the one with the highest
      # calculated_start_value so the generated migration covers every caller.
      def harvest_missing_sequences
        missing_sequences = {}

        DemoMode.personas.each_with_index do |persona, index|
          persona.variants.each_key do |variant|
            print_progress(persona, variant, index)
            generate_persona_in_rolled_back_transaction(persona, variant)
            collect_missing_into(missing_sequences)
          end
        end

        missing_sequences
      end

      def print_progress(persona, variant, index)
        progress = "Processing persona #{index + 1}/#{DemoMode.personas.count}: #{persona.name}:#{variant}"
        print "\r#{progress}".ljust(80)
      end

      def generate_persona_in_rolled_back_transaction(persona, variant)
        ActiveRecord::Base.transaction do
          persona.generate!(variant:)
          raise ActiveRecord::Rollback
        end
      end

      def collect_missing_into(missing_sequences)
        CleverSequence::PostgresBackend.sequence_cache.each_value do |result|
          next unless result.is_a?(CleverSequence::PostgresBackend::SequenceResult::Missing)

          existing = missing_sequences[result.sequence_name]
          if existing.nil? || result.calculated_start_value > existing.calculated_start_value
            missing_sequences[result.sequence_name] = result
          end
        end
      end
    end

    def initialize(sequence_data)
      @sequences = sequence_data
        .map { |data| normalize_sequence_data(data) }
        .sort_by { |s| s[:sequence_name] }
    end

    def up_sql
      lines = []
      lines << 'safety_assured do'
      lines << '  execute <<~SQL'
      @sequences.each do |seq|
        lines << "    CREATE SEQUENCE IF NOT EXISTS \"#{seq[:sequence_name]}\" START WITH #{seq[:start_value]};"
      end
      lines << '  SQL'
      lines << 'end'
      lines.join("\n")
    end

    def down_sql
      lines = []
      lines << 'safety_assured do'
      lines << '  execute <<~SQL'
      @sequences.each do |seq|
        lines << "    DROP SEQUENCE IF EXISTS \"#{seq[:sequence_name]}\";"
      end
      lines << '  SQL'
      lines << 'end'
      lines.join("\n")
    end

    def ci_output
      <<~OUTPUT
        ===== Missing CleverSequence Sequences =====

        The following PostgreSQL sequences are required but do not exist:
        #{sequence_list}

        To create a migration, run:
          bundle exec rails generate migration <YourMigrationName>

        Then add the following to your migration:

        def up
          #{up_sql.gsub("\n", "\n    ")}
        end

        def down
          #{down_sql.gsub("\n", "\n    ")}
        end
      OUTPUT
    end

    private

    def normalize_sequence_data(data)
      {
        sequence_name: data[:sequence_name],
        klass_name: data[:klass].name,
        attribute: data[:attribute].to_s,
        start_value: data[:calculated_start_value],
      }
    end

    def sequence_list
      @sequences.map { |seq|
        "  - #{seq[:sequence_name]} (#{seq[:klass_name]}##{seq[:attribute]}, start: #{seq[:start_value]})"
      }.join("\n")
    end
  end
end
# rubocop:enable Rails/Output
