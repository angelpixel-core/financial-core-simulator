# frozen_string_literal: true

require "bcrypt"

puts "Seeding verified runs..."

RUN_COUNT = 30 unless defined?(RUN_COUNT)
SEED_NAMESPACE = "verified-seed" unless defined?(SEED_NAMESPACE)

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

def build_input(day_offset:)
  timestamp = (Time.now.utc - day_offset.days).strftime("%Y-%m-%dT%H:%M:%SZ")
  price_shift = (day_offset % 7) * 50

  {
    "schemaVersion" => "1.0",
    "accounts" => ACCOUNT_IDS.map { |account_id| { "accountId" => account_id } },
    "markets" => MARKET_IDS.map { |market_id| { "marketId" => market_id } },
    "feeModel" => { "enabled" => true },
    "trades" => [
      {
        "tradeId" => "#{SEED_NAMESPACE}-trade-#{day_offset}",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => day_offset + 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => "0.5",
        "priceQuotePerBase" => (2200 + price_shift).to_s,
        "fee" => { "amountQuote" => "3" }
      }
    ],
    "priceSnapshot" => {
      "valuationTimestamp" => timestamp,
      "prices" => [
        { "marketId" => "ETH-USD", "priceQuotePerBase" => (2300 + price_shift).to_s },
        { "marketId" => "BTC-USD", "priceQuotePerBase" => (52000 + price_shift * 10).to_s }
      ],
      "fx" => { "quoteUsd" => "1" }
    }
  }
end

ACCOUNT_EMAILS.each_key do |email|
  upsert_account(email: email, password: PASSWORD)
end

runs = []

RUN_COUNT.times do |index|
  day_offset = RUN_COUNT - 1 - index
  input = build_input(day_offset: day_offset)

  run = Run.create!(
    input_json: input,
    created_at: Time.current.beginning_of_day - day_offset.days + 9.hours,
    updated_at: Time.current.beginning_of_day - day_offset.days + 9.hours
  )

  Runs::Execute.new.call(run)
  Runs::VerifyInputHash.new.call(run)

  runs << run
end

puts "Verified runs created: #{runs.length}"
puts "Latest run id: #{runs.last&.id}"
puts "Login credentials: ops@example.com / #{PASSWORD}
admin@example.com / #{PASSWORD}"
