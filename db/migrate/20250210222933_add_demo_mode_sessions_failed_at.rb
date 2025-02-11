# frozen_string_literal: true

class AddDemoModeSessionsFailedAt < ActiveRecord::Migration[5.1]
  def change
    add_column :demo_mode_sessions, :failed_at, :datetime, null: true, default: nil
  end
end
