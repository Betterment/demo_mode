# frozen_string_literal: true

class AddPersonaChecksumToDemoModeSessions < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :demo_mode_sessions, :persona_checksum, :string
  end
end
