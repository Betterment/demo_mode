# frozen_string_literal: true

class RenameSuccessfulToInUseInDemoModeSessions < ActiveRecord::Migration[5.1]
  def up
    safety_assured { execute "UPDATE demo_mode_sessions SET status = 'in_use' WHERE status = 'successful'" }
  end

  def down
    safety_assured { execute "UPDATE demo_mode_sessions SET status = 'successful' WHERE status = 'in_use'" }
  end
end
