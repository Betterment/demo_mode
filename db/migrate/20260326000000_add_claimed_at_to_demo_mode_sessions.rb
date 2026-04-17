# frozen_string_literal: true

class AddClaimedAtToDemoModeSessions < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :demo_mode_sessions, :claimed_at, :datetime

    reversible do |dir|
      dir.up { safety_assured { execute "UPDATE demo_mode_sessions SET claimed_at = created_at" } }
    end

    safety_assured do
      add_index :demo_mode_sessions,
        %i(persona_name variant),
        name: :index_demo_mode_sessions_on_pool_lookup,
        where: "status = 'available' AND claimed_at IS NULL",
        algorithm: :concurrently
    end
  end
end
