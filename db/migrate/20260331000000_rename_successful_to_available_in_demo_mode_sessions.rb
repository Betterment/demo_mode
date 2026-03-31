# frozen_string_literal: true

class RenameSuccessfulToAvailableInDemoModeSessions < ActiveRecord::Migration[5.1]
  def up
    execute "UPDATE demo_mode_sessions SET status = 'in_use' WHERE status = 'successful'"
  end

  def down
    execute "UPDATE demo_mode_sessions SET status = 'successful' WHERE status = 'in_use'"
  end
end
