# frozen_string_literal: true

class AddDemoModeSessionsError < ActiveRecord::Migration[5.1]
  def change
    add_column :demo_mode_sessions, :error, :string, null: true, default: nil,
                                                     comment: 'The error message, if any, that occurred during the creation of session.'
  end
end
