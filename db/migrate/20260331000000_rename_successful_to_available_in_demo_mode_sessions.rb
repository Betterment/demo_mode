# frozen_string_literal: true

class RenameSuccessfulToAvailableInDemoModeSessions < ActiveRecord::Migration[5.1]
  def up
    execute "UPDATE demo_mode_sessions SET status = 'available' WHERE status = 'successful'"
  end

  def down
    execute "UPDATE demo_mode_sessions SET status = 'successful' WHERE status = 'available'"
  end
end
