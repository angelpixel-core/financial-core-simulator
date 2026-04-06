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

ActiveRecord::Schema[8.1].define(version: 2026_04_02_120000) do
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

  create_table "demo_dataset_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "run_id"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.index ["created_at"], name: "index_demo_dataset_uploads_on_created_at"
    t.index ["run_id"], name: "index_demo_dataset_uploads_on_run_id"
  end

  create_table "fx_daily_rates", force: :cascade do |t|
    t.string "base_currency", null: false
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_role"
    t.jsonb "created_context", default: {}, null: false
    t.date "operational_date", null: false
    t.string "quote_currency", null: false
    t.decimal "rate", precision: 24, scale: 12
    t.string "source", null: false
    t.bigint "source_rate_id"
    t.bigint "source_run_id"
    t.bigint "source_upload_id"
    t.datetime "updated_at", null: false
    t.index ["operational_date", "base_currency", "quote_currency"], name: "idx_fx_daily_rates_unique", unique: true
    t.index ["source_rate_id"], name: "index_fx_daily_rates_on_source_rate_id"
    t.index ["source_run_id"], name: "index_fx_daily_rates_on_source_run_id"
    t.index ["source_upload_id"], name: "index_fx_daily_rates_on_source_upload_id"
  end

  create_table "fx_rate_gaps", force: :cascade do |t|
    t.string "base_currency", null: false
    t.datetime "created_at", null: false
    t.jsonb "created_context", default: {}, null: false
    t.datetime "ignored_at"
    t.date "operational_date", null: false
    t.bigint "placeholder_rate_id"
    t.string "quote_currency", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_rate_id"
    t.bigint "source_run_id"
    t.bigint "source_upload_id"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["operational_date", "base_currency", "quote_currency"], name: "idx_fx_rate_gaps_open", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["placeholder_rate_id"], name: "index_fx_rate_gaps_on_placeholder_rate_id"
    t.index ["resolved_rate_id"], name: "index_fx_rate_gaps_on_resolved_rate_id"
    t.index ["source_run_id"], name: "index_fx_rate_gaps_on_source_run_id"
    t.index ["source_upload_id"], name: "index_fx_rate_gaps_on_source_upload_id"
  end

  create_table "fx_rate_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by_id"
    t.string "created_by_role"
    t.jsonb "created_context", default: {}, null: false
    t.integer "error_count", default: 0, null: false
    t.text "error_message"
    t.string "file_path"
    t.string "original_filename"
    t.datetime "processed_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_fx_rate_uploads_on_created_at"
  end

  create_table "reporting_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "reporting_currency", default: "USD", null: false
    t.string "singleton_key", default: "reporting", null: false
    t.datetime "updated_at", null: false
    t.string "updated_by_id"
    t.string "updated_by_role"
    t.jsonb "updated_context", default: {}, null: false
    t.index ["singleton_key"], name: "index_reporting_settings_on_singleton_key", unique: true
  end

  create_table "run_daily_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_seq"
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "run_snapshot_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_snapshot_id", "event_seq"], name: "index_run_daily_events_on_run_snapshot_id_and_event_seq", unique: true
  end

  create_table "run_daily_pnls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "realized_pnl", precision: 24, scale: 12, null: false
    t.bigint "run_snapshot_id", null: false
    t.decimal "total_pnl", precision: 24, scale: 12, null: false
    t.decimal "unrealized_pnl", precision: 24, scale: 12, null: false
    t.datetime "updated_at", null: false
    t.index ["run_snapshot_id"], name: "idx_run_daily_pnls_snapshot", unique: true
  end

  create_table "run_daily_volumes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "notional_volume", precision: 24, scale: 12, null: false
    t.bigint "run_snapshot_id", null: false
    t.integer "trade_count", default: 0, null: false
    t.string "unit_code", null: false
    t.string "unit_type", null: false
    t.datetime "updated_at", null: false
    t.index ["run_snapshot_id"], name: "idx_run_daily_volumes_snapshot", unique: true
  end

  create_table "run_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "operational_date", null: false
    t.string "reporting_currency", null: false
    t.bigint "run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id", "operational_date", "reporting_currency"], name: "idx_run_snapshots_unique", unique: true
  end

  create_table "run_validation_errors", force: :cascade do |t|
    t.string "account_id"
    t.string "code"
    t.string "correlation_id"
    t.datetime "created_at", null: false
    t.string "event_type"
    t.string "field"
    t.string "market_id"
    t.text "message", default: "", null: false
    t.datetime "occurred_at"
    t.integer "row_index"
    t.bigint "run_id", null: false
    t.string "source"
    t.integer "timeline_seq"
    t.string "trade_id"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_run_validation_errors_on_created_at"
    t.index ["run_id"], name: "index_run_validation_errors_on_run_id"
  end

  create_table "runs", force: :cascade do |t|
    t.json "artifacts"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "engine_version"
    t.string "error_code"
    t.text "error_message"
    t.jsonb "fx_context"
    t.string "input_hash"
    t.json "input_json"
    t.string "output_dir"
    t.boolean "reliable", default: true, null: false
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
