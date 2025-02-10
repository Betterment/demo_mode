# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_05_05_000000) do

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "failed_at"
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "locked_at"
    t.string "locked_by"
    t.integer "priority", default: 0, null: false
    t.string "queue"
    t.datetime "run_at"
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "demo_mode_sessions", force: :cascade do |t|
    t.string "persona_name", null: false
    t.string "signinable_type"
    t.string "signinable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "variant", default: "default", null: false
    t.string "signinable_password", null: false
    t.index ["signinable_type", "signinable_id"], name: "index_demo_mode_sessions_on_signinable_type_and_signinable_id"
  end

  create_table "dummy_users", force: :cascade do |t|
    t.string "name"
  end

  create_table "widgets", force: :cascade do |t|
    t.bigint "integer_column"
    t.string "string_column"
    t.text "text_column"
    t.datetime "datetime_column"
    t.date "date_column"
    t.boolean "boolean_column"
    t.text "encrypted_column_crypt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
