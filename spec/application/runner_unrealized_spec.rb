# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"
require "tmpdir"

RSpec.describe FCS::Application::Runner do
  it "writes unrealizedPnLQuote using priceSnapshot" do
    Dir.mktmpdir do |dir|
      input = {
        "schemaVersion" => "1.0",
        "accounts" => [{ "accountId" => "acc-1" }],
        "markets" => [{ "marketId" => "ETH-USD" }],
        "feeModel" => { "enabled" => false },
        "trades" => [
          {
            "tradeId" => "b1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "100"
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }]
        }
      }

      input_path = File.join(dir, "input.json")
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, "out")
      path = described_class.new.run!(input_path: input_path, output_dir: out_dir, fee_enabled: false)

      payload = JSON.parse(File.read(path))
      m = payload["accounts"][0]["markets"][0]
      expect(m["unrealizedPnLQuote"]).to eq("100.0")
    end
  end
end
