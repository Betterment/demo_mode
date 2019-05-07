ActiveRecord::Schema.define do
  create_table :delayed_jobs do |t|
    t.integer :attempts, default: 0, null: false
    t.datetime :created_at, null: false
    t.datetime :failed_at
    t.text :handler, null: false
    t.text :last_error
    t.datetime :locked_at
    t.string :locked_by
    t.integer :priority, default: 0, null: false
    t.string :queue
    t.datetime :run_at
    t.datetime :updated_at, null: false
    t.index %i(priority run_at), name: :delayed_jobs_priority
  end

  create_table :dummy_users do |t|
    t.string :name
  end

  create_table :widgets, force: true do |t|
    t.bigint :integer_column
    t.string :string_column
    t.text :text_column
    t.datetime :datetime_column
    t.date :date_column
    t.boolean :boolean_column
    t.text :encrypted_column_crypt
    t.timestamps
  end
end
