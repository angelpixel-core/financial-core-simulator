# frozen_string_literal: true

require "bcrypt"

puts "Seeding local demo data..."

def upsert_account(email:, password:, status: :verified)
  account = Account.find_or_initialize_by(email: email)
  account.password_hash = BCrypt::Password.create(password)
  account.status = status
  account.save!
  account
end

def build_valid_input
  {
    "schemaVersion" => "1.0",
    "accounts" => [
      {"accountId" => "acc-1"},
      {"accountId" => "acc-2"}
    ],
    "markets" => [
      {"marketId" => "ETH-USD"},
      {"marketId" => "BTC-USD"}
    ],
    "feeModel" => {"enabled" => true},
    "trades" => [],
    "priceSnapshot" => {
      "valuationTimestamp" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      "prices" => [
        {"marketId" => "ETH-USD", "priceQuotePerBase" => "2500"},
        {"marketId" => "BTC-USD", "priceQuotePerBase" => "52000"}
      ],
      "fx" => {"quoteUsd" => "1"}
    }
  }
end

upsert_account(email: "ops@example.com", password: "secret-pass")
upsert_account(email: "admin@example.com", password: "secret-pass")

load Rails.root.join("script", "seed_verified_runs.rb")

puts "Done."
