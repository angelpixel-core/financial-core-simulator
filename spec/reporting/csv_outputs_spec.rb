# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"
require "tmpdir"

RSpec.describe "CSV outputs" do
  it "writes positions.csv and pnl.csv" do
    Dir.mktmpdir do |dir|
      input = {
        "schemaVersion" => "1.0",
        "accounts" => [{ "accountId" => "acc-1" }],
        "markets" => [{ "marketId" => "ETH-USD" }],
        "feeModel" => { "enabled" => true },
        "trades" => [
          {
            "tradeId" => "b1",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "100",
            "fee" => { "amountQuote" => "1" }
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }],
          "fx" => { "quoteUsd" => "1" }
        }
      }

      input_path = File.join(dir, "input.json")
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, "out")
      runner = FCS::Application::Runner.new
      runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true)

      expect(File).to exist(File.join(out_dir, "positions.csv"))
      expect(File).to exist(File.join(out_dir, "pnl.csv"))
      expect(File).to exist(File.join(out_dir, "result.json"))
    end
  end
end
