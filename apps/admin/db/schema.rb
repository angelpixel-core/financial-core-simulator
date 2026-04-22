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

ActiveRecord::Schema[8.1].define(version: 2026_04_21_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "access_control_account_roles", force: :cascade do |t|
    t.bigint "access_control_role_id", null: false
    t.bigint "account_id", null: false
    t.string "assigned_by_id"
    t.jsonb "assigned_context", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_control_role_id"], name: "index_access_control_account_roles_on_access_control_role_id"
    t.index ["account_id", "access_control_role_id"], name: "idx_access_control_account_roles_unique", unique: true
    t.index ["account_id"], name: "index_access_control_account_roles_on_account_id"
  end

  create_table "access_control_audit_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "outcome", null: false
    t.string "required_role"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_access_control_audit_logs_on_account_id"
    t.index ["action", "outcome"], name: "index_access_control_audit_logs_on_action_and_outcome"
    t.index ["created_at"], name: "index_access_control_audit_logs_on_created_at"
  end

  create_table "access_control_permissions", force: :cascade do |t|
    t.bigint "access_control_role_id", null: false
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "resource", null: false
    t.datetime "updated_at", null: false
    t.index ["access_control_role_id", "resource", "action"], name: "idx_access_control_permissions_unique", unique: true
    t.index ["access_control_role_id"], name: "index_access_control_permissions_on_access_control_role_id"
  end

  create_table "access_control_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.integer "level", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_access_control_roles_on_key", unique: true
  end

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

  create_table "demo_access_locks", force: :cascade do |t|
    t.datetime "acquired_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "holder_account_id"
    t.string "holder_email"
    t.string "singleton_key", default: "demo_access", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_demo_access_locks_on_expires_at"
    t.index ["singleton_key"], name: "index_demo_access_locks_on_singleton_key", unique: true
  end

  create_table "demo_dataset_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "normalized_filename"
    t.string "original_filename"
    t.bigint "run_id"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.index ["created_at"], name: "index_demo_dataset_uploads_on_created_at"
    t.index ["normalized_filename"], name: "idx_demo_dataset_uploads_normalized_filename_unique", unique: true, where: "(normalized_filename IS NOT NULL)"
    t.index ["run_id"], name: "index_demo_dataset_uploads_on_run_id"
  end

  create_table "demo_sandbox_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_reset_at"
    t.integer "last_reset_duration_ms"
    t.jsonb "last_reset_result", default: {}, null: false
    t.string "last_reset_status", default: "idle", null: false
    t.string "singleton_key", default: "demo_sandbox", null: false
    t.datetime "updated_at", null: false
    t.index ["last_reset_at"], name: "index_demo_sandbox_states_on_last_reset_at"
    t.index ["singleton_key"], name: "index_demo_sandbox_states_on_singleton_key", unique: true
  end

  create_table "demo_usage_events", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_id", null: false
    t.bigint "amount_bytes", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.string "reason"
    t.string "status", null: false
    t.index ["action", "actor_id", "created_at"], name: "idx_demo_usage_events_action_actor_created_at"
    t.index ["action", "created_at"], name: "index_demo_usage_events_on_action_and_created_at"
    t.index ["created_at"], name: "index_demo_usage_events_on_created_at"
    t.index ["status", "created_at"], name: "index_demo_usage_events_on_status_and_created_at"
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
    t.bigint "source_id"
    t.bigint "source_rate_id"
    t.bigint "source_run_id"
    t.bigint "source_upload_id"
    t.datetime "updated_at", null: false
    t.index ["operational_date", "base_currency", "quote_currency", "source_id"], name: "index_fx_daily_rates_on_date_currency_source", unique: true
    t.index ["operational_date", "base_currency", "quote_currency"], name: "idx_fx_daily_rates_unique", unique: true
    t.index ["source_id"], name: "index_fx_daily_rates_on_source_id"
    t.index ["source_rate_id"], name: "index_fx_daily_rates_on_source_rate_id"
    t.index ["source_run_id"], name: "index_fx_daily_rates_on_source_run_id"
    t.index ["source_upload_id"], name: "index_fx_daily_rates_on_source_upload_id"
  end

  create_table "fx_rate_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.uuid "event_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_fx_rate_events_on_event_id", unique: true
    t.index ["event_type"], name: "index_fx_rate_events_on_event_type"
    t.index ["metadata"], name: "index_fx_rate_events_on_metadata", using: :gin
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

  create_table "fx_rate_ingestions", force: :cascade do |t|
    t.string "causation_id"
    t.jsonb "context", default: {}, null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.datetime "finished_at"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "source_id", null: false
    t.datetime "started_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_fx_rate_ingestions_on_correlation_id"
    t.index ["source_id"], name: "index_fx_rate_ingestions_on_source_id"
    t.index ["status"], name: "index_fx_rate_ingestions_on_status"
  end

  create_table "fx_rate_lineages", force: :cascade do |t|
    t.string "base_currency", null: false
    t.string "causation_id"
    t.jsonb "context", default: {}, null: false
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.string "error_code"
    t.bigint "ingestion_id", null: false
    t.jsonb "normalized_payload", default: {}, null: false
    t.date "operational_date", null: false
    t.string "quote_currency", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "source_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["base_currency", "quote_currency"], name: "index_fx_rate_lineages_on_base_currency_and_quote_currency"
    t.index ["correlation_id"], name: "index_fx_rate_lineages_on_correlation_id"
    t.index ["ingestion_id", "operational_date"], name: "index_fx_rate_lineages_on_ingestion_id_and_operational_date"
    t.index ["ingestion_id"], name: "index_fx_rate_lineages_on_ingestion_id"
    t.index ["source_id"], name: "index_fx_rate_lineages_on_source_id"
  end

  create_table "fx_rate_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.string "version", null: false
    t.index ["code", "source_type", "version"], name: "index_fx_rate_sources_on_code_and_source_type_and_version", unique: true
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

  add_foreign_key "access_control_account_roles", "access_control_roles"
  add_foreign_key "access_control_account_roles", "accounts"
  add_foreign_key "access_control_audit_logs", "accounts"
  add_foreign_key "access_control_permissions", "access_control_roles"
  add_foreign_key "account_login_change_keys", "accounts", column: "id"
  add_foreign_key "account_password_reset_keys", "accounts", column: "id"
  add_foreign_key "account_remember_keys", "accounts", column: "id"
  add_foreign_key "account_verification_keys", "accounts", column: "id"
  add_foreign_key "fx_daily_rates", "fx_rate_sources", column: "source_id"
  add_foreign_key "fx_rate_ingestions", "fx_rate_sources", column: "source_id"
  add_foreign_key "fx_rate_lineages", "fx_rate_ingestions", column: "ingestion_id"
  add_foreign_key "fx_rate_lineages", "fx_rate_sources", column: "source_id"
end
