# frozen_string_literal: true

class AddDemoModeSessionsPassword < ActiveRecord::Migration[5.1]
  def change
    add_column :demo_mode_sessions, :signinable_password, :string, null: false, default: ''

    reversible do |dir|
      dir.up do
        change_column :demo_mode_sessions, :signinable_password, :string, null: false, default: nil
      end
    end
  end
end
