class AddDemoModeSessionsError < ActiveRecord::Migration[7.0]
  ignore_missing_comments

  def change
    add_column :demo_mode_sessions, :error, :string, null: false, default: 'default',
                                                     comment: 'The error message, if any, that occurred during the creation of session.'
  end
end
