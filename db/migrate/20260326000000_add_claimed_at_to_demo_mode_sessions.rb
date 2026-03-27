# frozen_string_literal: true

class AddClaimedAtToDemoModeSessions < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :demo_mode_sessions, :claimed_at, :datetime

    add_index :demo_mode_sessions,
      %i(persona_name variant status claimed_at),
      name: :index_demo_mode_sessions_on_pool_lookup,
      algorithm: :concurrently
  end
end
