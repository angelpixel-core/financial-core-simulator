# frozen_string_literal: true

input = {
  "schemaVersion" => "1.0",
  "accounts" => [{"accountId" => "acc-1"}],
  "markets" => [{"marketId" => "ETH-USD"}],
  "feeModel" => {"enabled" => true},
  "trades" => [],
  "priceSnapshot" => {
    "valuationTimestamp" => "2026-02-25T03:00:00Z",
    "prices" => [{"marketId" => "ETH-USD", "priceQuotePerBase" => "150"}]
  }
}

run = Run.create!(input_json: input)
Runs::Execute.new.call(run)

puts "OK run=#{run.id} status=#{run.status} input_hash=#{run.input_hash}"
puts "result.json: #{run.result_json_path}"
