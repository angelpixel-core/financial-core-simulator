# frozen_string_literal: true

puts "Seeding interactive runs (execute/verify)..."

SEED_NAMESPACE = "interactive-seed" unless defined?(SEED_NAMESPACE)
EXECUTE_COUNT = 5 unless defined?(EXECUTE_COUNT)
VERIFY_COUNT = 5 unless defined?(VERIFY_COUNT)

ACCOUNT_IDS = %w[acc-1 acc-2].freeze
MARKET_IDS = %w[ETH-USD BTC-USD].freeze

def build_input(seed:, offset: 0)
  timestamp = (Time.now.utc - offset.days).strftime("%Y-%m-%dT%H:%M:%SZ")
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

execute_runs = []
EXECUTE_COUNT.times do |index|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-execute-#{index}",
    input_json: build_input(seed: index, offset: index),
    status: :queued,
    created_at: Time.current - (index + 1).hours,
    updated_at: Time.current - (index + 1).hours
  )
  execute_runs << run
end

verify_runs = []
VERIFY_COUNT.times do |index|
  run = Run.create!(
    run_uuid: "#{SEED_NAMESPACE}-verify-#{index}",
    input_json: build_input(seed: index + 100, offset: index),
    created_at: Time.current - (index + 1).days,
    updated_at: Time.current - (index + 1).days
  )

  Runs::Execute.new.call(run)
  run.update!(verification_status: "unverified", verified_at: nil, verification_input_hash: nil)
  verify_runs << run
end

puts "Interactive execute runs: #{execute_runs.map(&:id).join(", ")}
Interactive verify runs: #{verify_runs.map(&:id).join(", ")}"