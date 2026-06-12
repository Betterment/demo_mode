# frozen_string_literal: true

require 'rails/generators/base'
require 'rails/generators/active_record'
require 'demo_mode/clever_sequence/postgres_backend'

module DemoMode
  # Generates a migration that creates the PostgreSQL sequence backing a
  # CleverSequence, in response to
  # CleverSequence::PostgresBackend::SequenceNotFoundError.
  #
  #   bundle exec rails generate demo_mode:clever_sequence Widget integer_column
  #
  # By default the migration is written to the app's primary db/migrate path.
  # Use --database to target a connection's migrations_paths (from
  # config/database.yml), or --migrations-path to write to an explicit
  # directory (e.g. an engine's migrate dir in a monorepo).
  class CleverSequenceGenerator < Rails::Generators::Base
    include ActiveRecord::Generators::Migration

    desc 'Creates a migration that creates the PostgreSQL sequence backing a CleverSequence.'
    source_root File.expand_path('../templates', __dir__)

    argument :model, type: :string, banner: 'Model'
    argument :attribute, type: :string, banner: 'attribute'

    class_option :database, type: :string, aliases: %w[--db],
                            desc: "The database whose migrations_paths to use (from config/database.yml)."
    class_option :migrations_path, type: :string,
                                   desc: 'Explicit directory to write the migration into (overrides --database and the default).'

    def create_sequence_migration
      migration_template(
        'clever_sequence_migration.rb.tt',
        File.join(target_migrate_path, "create_clever_sequence_#{sequence_name}.rb"),
      )
    end

    no_tasks do
      def sequence_name
        CleverSequence::PostgresBackend.sequence_name(model_class, attribute)
      end

      def migration_class_name
        "CreateCleverSequence#{sequence_name.camelize}"
      end

      def migration_version
        "[#{ActiveRecord::Migration.current_version}]"
      end

      def table_name
        model_class.table_name
      end

      # The DB column the sequence advances past. Resolves attribute aliases
      # the same way CleverSequence::PostgresBackend does.
      def column_name
        model_class.attribute_aliases.fetch(attribute.to_s, attribute.to_s)
      end

      # Whether the backing column is an integer, so seeding the sequence
      # past MAX(column) is meaningful. Other columns (e.g. a string column)
      # are created at their default start; runtime adjustment handles
      # advancing them.
      def integer_column?
        model_class.columns_hash[column_name]&.type == :integer
      end

      private

      # Where the migration is written. An explicit --migrations-path wins;
      # otherwise fall back to Rails' resolution (db_migrate_path), which
      # honors --database via config/database.yml's migrations_paths.
      def target_migrate_path
        options[:migrations_path].presence || db_migrate_path
      end

      def model_class
        @model_class ||= model.camelize.constantize
      end
    end
  end
end
