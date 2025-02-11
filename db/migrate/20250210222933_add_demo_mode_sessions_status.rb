# frozen_string_literal: true

class AddDemoModeSessionsStatus < ActiveRecord::Migration[5.1]
  def change
    add_column :demo_mode_sessions, :status, :string, null: false, default: 'processing'

    reversible do |dir|
      dir.up do
        DemoMode::Session.update_all(status: 'successful') # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
