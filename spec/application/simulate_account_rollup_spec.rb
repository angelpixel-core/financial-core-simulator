# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"
require "tmpdir"

RSpec.describe FCS::Application::Simulate do
  describe "#call" do
    it "keeps account state isolated for interleaved trades in the same market" do
      input = {
        "accounts" => [{ "accountId" => "acc-a" }, { "accountId" => "acc-b" }],
        "markets" => [{ "marketId" => "ETH-USD" }],
        "feeModel" => { "enabled" => false },
        "trades" => [
          {
            "tradeId" => "t-1",
            "accountId" => "acc-a",
            "marketId" => "ETH-USD",
            "timestamp" => 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "100"
          },
          {
            "tradeId" => "t-2",
            "accountId" => "acc-b",
            "marketId" => "ETH-USD",
            "timestamp" => 2,
            "seq" => 2,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "200"
          },
          {
            "tradeId" => "t-3",
            "accountId" => "acc-a",
            "marketId" => "ETH-USD",
            "timestamp" => 3,
            "seq" => 3,
            "side" => "SELL",
            "quantityBase" => "1",
            "priceQuotePerBase" => "120"
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [{ "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }],
          "fx" => { "quoteUsd" => "1" }
        }
      }

      result = described_class.new.call(input)
      by_account = result.fetch("accounts").each_with_object({}) do |account, acc|
        acc[account.fetch("accountId")] = account
      end

      market_a = by_account.fetch("acc-a").fetch("markets").first
      market_b = by_account.fetch("acc-b").fetch("markets").first

      expect(market_a.fetch("quantity")).to eq("1.0")
      expect(market_a.fetch("avgCost")).to eq("100.0")
      expect(market_a.fetch("feesQuote")).to eq("0.0")
      expect(market_a.fetch("realizedPnL")).to eq("20.0")
      expect(market_a.fetch("realizedPnLQuote")).to eq("20.0")
      expect(market_a.fetch("unrealizedPnL")).to eq("50.0")
      expect(market_a.fetch("unrealizedPnLQuote")).to eq("50.0")
      expect(market_a.fetch("totalPnLQuote")).to eq("70.0")

      expect(market_b.fetch("quantity")).to eq("1.0")
      expect(market_b.fetch("avgCost")).to eq("200.0")
      expect(market_b.fetch("feesQuote")).to eq("0.0")
      expect(market_b.fetch("realizedPnL")).to eq("0.0")
      expect(market_b.fetch("realizedPnLQuote")).to eq("0.0")
      expect(market_b.fetch("unrealizedPnL")).to eq("-50.0")
      expect(market_b.fetch("unrealizedPnLQuote")).to eq("-50.0")
      expect(market_b.fetch("totalPnLQuote")).to eq("-50.0")
    end

    it "keeps account state isolated for interleaved trades across shared markets" do
      input = {
        "accounts" => [{ "accountId" => "acc-a" }, { "accountId" => "acc-b" }],
        "markets" => [{ "marketId" => "ETH-USD" }, { "marketId" => "BTC-USD" }],
        "feeModel" => { "enabled" => false },
        "trades" => [
          {
            "tradeId" => "t-1",
            "accountId" => "acc-a",
            "marketId" => "ETH-USD",
            "timestamp" => 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "100"
          },
          {
            "tradeId" => "t-2",
            "accountId" => "acc-b",
            "marketId" => "ETH-USD",
            "timestamp" => 2,
            "seq" => 2,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "200"
          },
          {
            "tradeId" => "t-3",
            "accountId" => "acc-a",
            "marketId" => "BTC-USD",
            "timestamp" => 3,
            "seq" => 3,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "50"
          },
          {
            "tradeId" => "t-4",
            "accountId" => "acc-b",
            "marketId" => "BTC-USD",
            "timestamp" => 4,
            "seq" => 4,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "70"
          },
          {
            "tradeId" => "t-5",
            "accountId" => "acc-b",
            "marketId" => "BTC-USD",
            "timestamp" => 5,
            "seq" => 5,
            "side" => "SELL",
            "quantityBase" => "1",
            "priceQuotePerBase" => "75"
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [
            { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" },
            { "marketId" => "BTC-USD", "priceQuotePerBase" => "60" }
          ],
          "fx" => { "quoteUsd" => "1" }
        }
      }

      result = described_class.new.call(input)
      by_account = result.fetch("accounts").each_with_object({}) do |account, acc|
        acc[account.fetch("accountId")] = account.fetch("markets").each_with_object({}) do |market, m|
          m[market.fetch("marketId")] = market
        end
      end

      expect(by_account.fetch("acc-a").fetch("ETH-USD").fetch("avgCost")).to eq("100.0")
      expect(by_account.fetch("acc-b").fetch("ETH-USD").fetch("avgCost")).to eq("200.0")
      expect(by_account.fetch("acc-a").fetch("BTC-USD").fetch("quantity")).to eq("2.0")
      expect(by_account.fetch("acc-b").fetch("BTC-USD").fetch("quantity")).to eq("1.0")
      expect(by_account.fetch("acc-a").fetch("ETH-USD").fetch("feesQuote")).to eq("0.0")
      expect(by_account.fetch("acc-b").fetch("ETH-USD").fetch("feesQuote")).to eq("0.0")
      expect(by_account.fetch("acc-a").fetch("ETH-USD").fetch("realizedNetPnLQuote")).to eq("0.0")
      expect(by_account.fetch("acc-b").fetch("ETH-USD").fetch("realizedNetPnLQuote")).to eq("0.0")
      expect(by_account.fetch("acc-a").fetch("ETH-USD").fetch("totalPnLQuote")).to eq("50.0")
      expect(by_account.fetch("acc-b").fetch("ETH-USD").fetch("totalPnLQuote")).to eq("-50.0")
    end

    it "builds global totals from account totals and emits deterministic account/market ordering" do
      input = {
        "accounts" => [{ "accountId" => "acc-2" }, { "accountId" => "acc-1" }],
        "markets" => [{ "marketId" => "BTC-USD" }, { "marketId" => "ETH-USD" }],
        "feeModel" => { "enabled" => false },
        "trades" => [
          {
            "tradeId" => "t-1",
            "accountId" => "acc-2",
            "marketId" => "BTC-USD",
            "timestamp" => 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "1",
            "priceQuotePerBase" => "50000"
          },
          {
            "tradeId" => "t-2",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => 2,
            "seq" => 2,
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "100"
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [
            { "marketId" => "BTC-USD", "priceQuotePerBase" => "50010" },
            { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }
          ],
          "fx" => { "quoteUsd" => "1" }
        }
      }

      result = described_class.new.call(input)
      accounts = result.fetch("accounts")

      expect(accounts.map { |account| account.fetch("accountId") }).to eq(%w[acc-1 acc-2])
      accounts.each do |account|
        expect(account.fetch("markets").map { |market| market.fetch("marketId") }).to eq(%w[BTC-USD ETH-USD])
      end

      realized_sum = sum_account_total(accounts, "realizedPnLQuote")
      fees_sum = sum_account_total(accounts, "feesQuote")
      realized_net_sum = sum_account_total(accounts, "realizedNetPnLQuote")
      unrealized_sum = sum_account_total(accounts, "unrealizedPnLQuote")
      total_sum = sum_account_total(accounts, "totalPnLQuote")

      global = result.fetch("global")

      expect(global.fetch("realizedPnLQuote")).to eq(realized_sum.to_s)
      expect(global.fetch("feesQuote")).to eq(fees_sum.to_s)
      expect(global.fetch("realizedNetPnLQuote")).to eq(realized_net_sum.to_s)
      expect(global.fetch("unrealizedPnLQuote")).to eq(unrealized_sum.to_s)
      expect(global.fetch("totalPnLQuote")).to eq(total_sum.to_s)
      expect(global.fetch("totalPnLUsd")).to eq(total_sum.to_s)
    end

    it "keeps direct Simulate results deterministic for reordered batch trades with " \
       "tie-break collisions, sells, and fees" do
      trades_a = [
        {
          "tradeId" => "t-z",
          "accountId" => "acc-2",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "1",
          "priceQuotePerBase" => "100",
          "fee" => { "amountQuote" => "1" }
        },
        {
          "tradeId" => "t-a",
          "accountId" => "acc-1",
          "marketId" => "BTC-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "2",
          "priceQuotePerBase" => "50",
          "fee" => { "amountQuote" => "1" }
        },
        {
          "tradeId" => "t-m",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "timestamp" => 1,
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "1",
          "priceQuotePerBase" => "120",
          "fee" => { "amountQuote" => "1" }
        },
        {
          "tradeId" => "t-sell",
          "accountId" => "acc-1",
          "marketId" => "BTC-USD",
          "timestamp" => 2,
          "seq" => 2,
          "side" => "SELL",
          "quantityBase" => "1",
          "priceQuotePerBase" => "65",
          "fee" => { "amountQuote" => "1" }
        }
      ]

      trades_b = trades_a.reverse

      input_a = {
        "accounts" => [{ "accountId" => "acc-2" }, { "accountId" => "acc-1" }],
        "markets" => [{ "marketId" => "ETH-USD" }, { "marketId" => "BTC-USD" }],
        "feeModel" => { "enabled" => true },
        "trades" => trades_a,
        "priceSnapshot" => {
          "valuationTimestamp" => "2026-02-25T03:00:00Z",
          "prices" => [
            { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" },
            { "marketId" => "BTC-USD", "priceQuotePerBase" => "60" }
          ],
          "fx" => { "quoteUsd" => "1" }
        }
      }

      input_b = input_a.merge("trades" => trades_b)

      result_a = described_class.new.call(input_a)
      result_b = described_class.new.call(input_b)

      expect(result_a).to eq(result_b)

      by_account = result_a.fetch("accounts").each_with_object({}) do |account, acc|
        acc[account.fetch("accountId")] = account.fetch("markets").each_with_object({}) do |market, m|
          m[market.fetch("marketId")] = market
        end
      end

      expect(by_account.fetch("acc-1").fetch("BTC-USD")).to include(
        "quantity" => "1.0",
        "realizedPnLQuote" => "15.0",
        "feesQuote" => "2.0",
        "realizedNetPnLQuote" => "13.0"
      )
    end

    it "keeps identical inputHash and canonical artifacts across reruns for multi-account input" do
      Dir.mktmpdir do |tmp|
        input = {
          "schemaVersion" => "1.0",
          "accounts" => [{ "accountId" => "acc-2" }, { "accountId" => "acc-1" }],
          "markets" => [{ "marketId" => "BTC-USD" }, { "marketId" => "ETH-USD" }],
          "feeModel" => { "enabled" => false },
          "trades" => [
            {
              "tradeId" => "t-1",
              "accountId" => "acc-2",
              "marketId" => "BTC-USD",
              "timestamp" => 1,
              "seq" => 1,
              "side" => "BUY",
              "quantityBase" => "1",
              "priceQuotePerBase" => "50000"
            },
            {
              "tradeId" => "t-2",
              "accountId" => "acc-1",
              "marketId" => "ETH-USD",
              "timestamp" => 2,
              "seq" => 2,
              "side" => "BUY",
              "quantityBase" => "2",
              "priceQuotePerBase" => "100"
            }
          ],
          "priceSnapshot" => {
            "valuationTimestamp" => "2026-02-25T03:00:00Z",
            "prices" => [
              { "marketId" => "BTC-USD", "priceQuotePerBase" => "50010" },
              { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }
            ],
            "fx" => { "quoteUsd" => "1" }
          }
        }

        input_path = File.join(tmp, "input.json")
        File.write(input_path, JSON.pretty_generate(input))

        runner = FCS::Application::Runner.new
        out1 = File.join(tmp, "out-1")
        out2 = File.join(tmp, "out-2")
        json1 = runner.run!(input_path: input_path, output_dir: out1, fee_enabled: false)
        json2 = runner.run!(input_path: input_path, output_dir: out2, fee_enabled: false)

        payload1 = JSON.parse(File.read(json1))
        payload2 = JSON.parse(File.read(json2))

        expect(payload1.fetch("inputHash")).to eq(payload2.fetch("inputHash"))
        %w[result.json positions.csv pnl.csv].each do |name|
          expect(File.read(File.join(out1, name))).to eq(File.read(File.join(out2, name)))
        end
      end
    end

    it "keeps identical inputHash and canonical artifacts across timeline reruns for multi-account input" do
      previous = ENV.fetch("FCS_TIMELINE_ENABLED", nil)
      ENV["FCS_TIMELINE_ENABLED"] = "1"

      Dir.mktmpdir do |tmp|
        input = {
          "schemaVersion" => "1.0",
          "accounts" => [{ "accountId" => "acc-2" }, { "accountId" => "acc-1" }],
          "markets" => [{ "marketId" => "BTC-USD" }, { "marketId" => "ETH-USD" }],
          "feeModel" => { "enabled" => false },
          "trades" => [],
          "timeline" => {
            "events" => [
              {
                "eventType" => "TRADE_APPLIED",
                "timelineSeq" => 1,
                "timestamp" => "2026-03-03T12:00:01Z",
                "source" => "sim.core",
                "externalId" => "tr-1",
                "trade" => {
                  "tradeId" => "t-1",
                  "accountId" => "acc-2",
                  "marketId" => "BTC-USD",
                  "timestamp" => 1,
                  "seq" => 1,
                  "side" => "BUY",
                  "quantityBase" => "1",
                  "priceQuotePerBase" => "50000"
                }
              },
              {
                "eventType" => "TRADE_APPLIED",
                "timelineSeq" => 2,
                "timestamp" => "2026-03-03T12:00:02Z",
                "source" => "sim.core",
                "externalId" => "tr-2",
                "trade" => {
                  "tradeId" => "t-2",
                  "accountId" => "acc-1",
                  "marketId" => "ETH-USD",
                  "timestamp" => 2,
                  "seq" => 2,
                  "side" => "BUY",
                  "quantityBase" => "2",
                  "priceQuotePerBase" => "100"
                }
              }
            ]
          },
          "priceSnapshot" => {
            "valuationTimestamp" => "2026-02-25T03:00:00Z",
            "prices" => [
              { "marketId" => "BTC-USD", "priceQuotePerBase" => "50010" },
              { "marketId" => "ETH-USD", "priceQuotePerBase" => "150" }
            ],
            "fx" => { "quoteUsd" => "1" }
          }
        }

        input_path = File.join(tmp, "input.json")
        File.write(input_path, JSON.pretty_generate(input))

        runner = FCS::Application::Runner.new
        out1 = File.join(tmp, "out-1")
        out2 = File.join(tmp, "out-2")
        json1 = runner.run!(input_path: input_path, output_dir: out1, fee_enabled: false)
        json2 = runner.run!(input_path: input_path, output_dir: out2, fee_enabled: false)

        payload1 = JSON.parse(File.read(json1))
        payload2 = JSON.parse(File.read(json2))

        expect(payload1.fetch("inputHash")).to eq(payload2.fetch("inputHash"))
        %w[result.json positions.csv pnl.csv].each do |name|
          expect(File.read(File.join(out1, name))).to eq(File.read(File.join(out2, name)))
        end
      end
    ensure
      ENV["FCS_TIMELINE_ENABLED"] = previous
    end
  end

  def sum_account_total(accounts, field)
    accounts.inject(FCS::Types::Decimal18.new(0)) do |sum, account|
      sum + FCS::Types::Decimal18.from_string(account.fetch("totals").fetch(field))
    end
  end
end
