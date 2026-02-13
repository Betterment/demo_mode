# frozen_string_literal: true

class CleverSequence
  module DatabaseBackend
    SEQUENCE_PREFIX = 'clever_seq_'

    class << self
      def nextval(klass, attribute, block)
        name = sequence_name(klass, attribute)
        ensure_sequence_exists!(klass, attribute, name, block)

        result = ActiveRecord::Base.connection.execute(
          "SELECT nextval('#{name}')",
        )
        result.first['nextval'].to_i
      end

      def sequence_name(klass, attribute)
        table = klass.table_name.gsub(/[^a-z0-9_]/i, '_')
        attr = attribute.to_s.gsub(/[^a-z0-9_]/i, '_')
        "#{SEQUENCE_PREFIX}#{table}_#{attr}"[0, 63] # PostgreSQL identifier limit
      end

      def ensure_sequence_exists!(klass, attribute, name, block)
        return if sequence_verified?(name)

        create_sequence_if_not_exists(klass, attribute, name, block)
        mark_sequence_verified!(name)
      end

      def reset_verified_sequences!
        verified_sequences.clear
      end

      def drop_all_sequences!
        ActiveRecord::Base.connection.execute(<<-SQL.squish)
          DO $$
          DECLARE
            seq_name TEXT;
          BEGIN
            FOR seq_name IN
              SELECT sequence_name
              FROM information_schema.sequences
              WHERE sequence_name LIKE '#{SEQUENCE_PREFIX}%'
            LOOP
              EXECUTE 'DROP SEQUENCE IF EXISTS ' || seq_name;
            END LOOP;
          END $$;
        SQL
        reset_verified_sequences!
      end

      private

      def verified_sequences
        @verified_sequences ||= Concurrent::Set.new
      end

      def sequence_verified?(name)
        verified_sequences.include?(name)
      end

      def mark_sequence_verified!(name)
        verified_sequences.add(name)
      end

      def create_sequence_if_not_exists(klass, attribute, name, block)
        starting_value = calculate_starting_value(klass, attribute, block)

        ActiveRecord::Base.connection.execute(<<-SQL.squish)
          DO $$
          BEGIN
            IF NOT EXISTS (
              SELECT 1 FROM information_schema.sequences
              WHERE sequence_name = '#{name}'
            ) THEN
              CREATE SEQUENCE #{name} START WITH #{starting_value + 1};
            END IF;
          END $$;
        SQL
      rescue ActiveRecord::StatementInvalid => e
        # Handle race condition where another process created it
        raise unless e.message.include?('already exists')
      end

      def calculate_starting_value(klass, attribute, block)
        column_name = klass.attribute_aliases[attribute.to_s] || attribute.to_s
        return 0 unless klass.column_names.include?(column_name)

        # For integer columns, use MAX for efficiency
        if klass.columns_hash[column_name]&.type == :integer
          klass.maximum(column_name) || 0
        else
          # Fall back to LowerBoundFinder for non-integer columns
          LowerBoundFinder.new(klass, column_name, block).lower_bound
        end
      end
    end
  end
end