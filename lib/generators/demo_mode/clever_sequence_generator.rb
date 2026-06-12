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
  class CleverSequenceGenerator < Rails::Generators::Base
    include ActiveRecord::Generators::Migration

    desc 'Creates a migration that creates the PostgreSQL sequence backing a CleverSequence.'
    source_root File.expand_path('../templates', __dir__)

    argument :model, type: :string, banner: 'Model'
    argument :attribute, type: :string, banner: 'attribute'

    def create_sequence_migration
      migration_template(
        'clever_sequence_migration.rb.tt',
        "db/migrate/create_clever_sequence_#{sequence_name}.rb",
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

      private

      def model_class
        @model_class ||= model.camelize.constantize
      end
    end
  end
end
