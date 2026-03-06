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

ActiveRecord::Schema[8.1].define(version: 2026_03_06_054552) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "account_login_change_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
    t.string "login", null: false
  end

  create_table "account_password_reset_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "account_remember_keys", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.string "key", null: false
  end

  create_table "account_verification_keys", force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "accounts", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true, where: "(status = ANY (ARRAY[1, 2]))"
    t.check_constraint "email ~ '^[^,;@ \r\n]+@[^,@; \r\n]+.[^,@; \r\n]+$'::citext", name: "valid_email"
  end

  create_table "runs", force: :cascade do |t|
    t.json "artifacts"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "engine_version"
    t.string "error_code"
    t.text "error_message"
    t.string "input_hash"
    t.json "input_json"
    t.string "output_dir"
    t.string "run_uuid"
    t.string "schema_version"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.datetime "valuation_timestamp"
    t.text "verification_error"
    t.string "verification_input_hash"
    t.string "verification_status"
    t.datetime "verified_at"
    t.index ["input_hash"], name: "index_runs_on_input_hash"
    t.index ["run_uuid"], name: "index_runs_on_run_uuid", unique: true
    t.index ["status"], name: "index_runs_on_status"
    t.index ["verification_status"], name: "index_runs_on_verification_status"
  end

  add_foreign_key "account_login_change_keys", "accounts", column: "id"
  add_foreign_key "account_password_reset_keys", "accounts", column: "id"
  add_foreign_key "account_remember_keys", "accounts", column: "id"
  add_foreign_key "account_verification_keys", "accounts", column: "id"
end
