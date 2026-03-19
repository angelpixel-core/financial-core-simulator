# frozen_string_literal: true

require "bcrypt"

puts "Seeding daily ops scenarios..."

SEED_NAMESPACE = "ops-daily" unless defined?(SEED_NAMESPACE)
TODAY = Time.now.utc

ACCOUNT_EMAILS = {
  "ops@example.com" => "operator",
  "admin@example.com" => "admin"
}.freeze

PASSWORD = "secret-pass"
ACCOUNT_IDS = %w[acc-1 acc-2 acc-3].freeze
MARKET_IDS = %w[ETH-USD BTC-USD].freeze

def upsert_account(email:, password:, status: :verified)
  account = Account.find_or_initialize_by(email: email)
  account.password_hash = BCrypt::Password.create(password)
  account.status = status
  account.save!
  account
end

def build_input(seed:, offset_days: 0)
  timestamp = (TODAY - offset_days.days).strftime("%Y-%m-%dT%H:%M:%SZ")
  price_shift = seed * 25

  {
    "schemaVersion" => "1.0",
    "accounts" => ACCOUNT_IDS.map { |account_id| { "accountId" => account_id } },
    "markets" => MARKET_IDS.map { |market_id| { "marketId" => market_id } },
    "feeModel" => { "enabled" => true },
    "trades" => [
      {
        "tradeId" => "#{SEED_NAMESPACE}-trade-#{seed}",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => seed + 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => "0.4",
        "priceQuotePerBase" => (2200 + price_shift).to_s,
        "fee" => { "amountQuote" => "2" }
      }
    ],
    "priceSnapshot" => {
      "valuationTimestamp" => timestamp,
      "prices" => [
        { "marketId" => "ETH-USD", "priceQuotePerBase" => (2300 + price_shift).to_s },
        { "marketId" => "BTC-USD", "priceQuotePerBase" => (52000 + price_shift * 8).to_s }
      ],
      "fx" => { "quoteUsd" => "1" }
    }
  }
end

ACCOUNT_EMAILS.each_key do |email|
  upsert_account(email: email, password: PASSWORD)
end

verified_ids = []
verify_ids = []
execute_ids = []
running_ids = []
failed_ids = []
mismatch_ids = []
verification_error_ids = []

# 10 verified runs over the last 10 days
10.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-verified-#{i}",
    input_json: build_input(seed: i, offset_days: i),
    created_at: TODAY - i.days + 9.hours,
    updated_at: TODAY - i.days + 9.hours
  )
  Runs::Execute.new.call(run)
  Runs::VerifyInputHash.new.call(run)
  verified_ids << run.id
end

# 5 runs ready for manual verification (executed but unverified)
5.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-verify-#{i}",
    input_json: build_input(seed: i + 100, offset_days: i + 1),
    created_at: TODAY - (i + 1).days + 11.hours,
    updated_at: TODAY - (i + 1).days + 11.hours
  )
  Runs::Execute.new.call(run)
  run.update!(verification_status: "unverified", verified_at: nil, verification_input_hash: nil)
  verify_ids << run.id
end

# 5 runs ready for manual execution (queued)
5.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-execute-#{i}",
    input_json: build_input(seed: i + 200, offset_days: 0),
    status: :queued,
    created_at: TODAY - i.hours,
    updated_at: TODAY - i.hours
  )
  execute_ids << run.id
end

# 2 running runs
2.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-running-#{i}",
    input_json: build_input(seed: i + 300, offset_days: 0),
    status: :running,
    created_at: TODAY - (i + 1).hours,
    updated_at: TODAY - (i + 1).hours
  )
  running_ids << run.id
end

# 3 failed validation runs
3.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-failed-#{i}",
    input_json: { "schemaVersion" => "1.0" },
    status: :failed,
    error_code: "ERR_VALIDATION_GENERAL",
    error_message: "Missing required field",
    created_at: TODAY - (i + 2).days + 2.hours,
    updated_at: TODAY - (i + 2).days + 2.hours
  )
  failed_ids << run.id
end

# 2 mismatch runs (input_hash changed after execution)
2.times do |i|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-mismatch-#{i}",
    input_json: build_input(seed: i + 400, offset_days: i + 3),
    created_at: TODAY - (i + 3).days + 5.hours,
    updated_at: TODAY - (i + 3).days + 5.hours
  )
  Runs::Execute.new.call(run)
  Runs::VerifyInputHash.new.call(run)
  run.update!(input_hash: "mismatch-#{run.input_hash}")
  mismatch_ids << run.id
end

# 1 verification error run (missing input hash)
run = Run.create!(
  run_uuid: "#{SEED_NAMESPACE}-verification-error",
  input_json: {},
  status: :succeeded,
  created_at: TODAY - 1.day + 6.hours,
  updated_at: TODAY - 1.day + 6.hours,
  input_hash: nil
)
Runs::VerifyInputHash.new.call(run)
verification_error_ids << run.id

puts "Done."
puts "Verified runs (no action needed): #{verified_ids.join(", ")}" unless verified_ids.empty?
puts "Runs to verify (click Verify now): #{verify_ids.join(", ")}" unless verify_ids.empty?
puts "Runs to execute (click Execute now): #{execute_ids.join(", ")}" unless execute_ids.empty?
puts "Running runs (in-progress): #{running_ids.join(", ")}" unless running_ids.empty?
puts "Failed validation runs: #{failed_ids.join(", ")}" unless failed_ids.empty?
puts "Mismatch runs: #{mismatch_ids.join(", ")}" unless mismatch_ids.empty?
puts "Verification error runs: #{verification_error_ids.join(", ")}" unless verification_error_ids.empty?
puts "Login credentials: ops@example.com / #{PASSWORD}
admin@example.com / #{PASSWORD}"
