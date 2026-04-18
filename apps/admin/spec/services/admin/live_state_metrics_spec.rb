require "rails_helper"
require "json"
require "fileutils"

RSpec.describe Admin::LiveStateMetrics do
  describe "#call" do
    it "returns checkpoint-derived top accounts and global totals from latest checkpoint" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "latest")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"}, output_dir: base_dir.to_s)

      File.write(
        File.join(base_dir, "checkpoint_2.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 2,
            "state" => {
              "global" => {"totalPnLQuote" => "10.0"},
              "accounts" => [
                {"accountId" => "acc-old",
                 "totals" => {"totalPnLQuote" => "10.0", "realizedNetPnLQuote" => "5.0",
                              "unrealizedPnLQuote" => "5.0"}}
              ]
            }
          }
        )
      )

      File.write(
        File.join(base_dir, "checkpoint_8.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 8,
            "state" => {
              "global" => {"totalPnLQuote" => "42.0", "realizedNetPnLQuote" => "30.0",
                           "unrealizedPnLQuote" => "12.0"},
              "accounts" => [
                {"accountId" => "acc-b",
                 "totals" => {"totalPnLQuote" => "5.0", "realizedNetPnLQuote" => "2.0",
                              "unrealizedPnLQuote" => "3.0"}},
                {"accountId" => "acc-a",
                 "totals" => {"totalPnLQuote" => "20.0", "realizedNetPnLQuote" => "11.0",
                              "unrealizedPnLQuote" => "9.0"}}
              ]
            }
          }
        )
      )

      metrics = described_class.new.call

      expect(metrics[:checkpoint_timeline_seq]).to eq(8)
      expect(metrics[:latest_global]).to include("totalPnLQuote" => "42.0")
      expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq(%w[acc-a acc-b])
      expect(metrics[:top_accounts].first[:total_pnl_quote]).to eq(BigDecimal("20.0"))
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end

    it "returns nil when no checkpoint files are available" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "empty")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"}, output_dir: base_dir.to_s)

      expect(described_class.new.call).to be_nil
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end

    it "returns nil when checkpoint payload is invalid" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "invalid")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"}, output_dir: base_dir.to_s)
      File.write(File.join(base_dir, "checkpoint_3.json"), "{broken-json")

      expect(described_class.new.call).to be_nil
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end

    it "derives top_accounts from markets when checkpoint has no totals" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "positions_only")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(
        status: :succeeded,
        input_json: {
          "schemaVersion" => "1.0",
          "priceSnapshot" => {
            "prices" => [
              {"marketId" => "BTC-USD", "priceQuotePerBase" => "60000"}
            ]
          }
        },
        output_dir: base_dir.to_s
      )
      File.write(
        File.join(base_dir, "checkpoint_6.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 6,
            "state" => {
              "accounts" => [
                {
                  "accountId" => "acc-1",
                  "markets" => [
                    {"marketId" => "BTC-USD", "quantity" => "0.5", "avgCost" => "59000"}
                  ]
                }
              ]
            }
          }
        )
      )

      metrics = described_class.new.call

      expect(metrics[:checkpoint_timeline_seq]).to eq(6)
      expect(metrics[:top_accounts]).to be_present
      expect(metrics[:top_accounts].first[:account_id]).to eq("acc-1")
      expect(metrics[:top_accounts].first[:realized_net_pnl_quote]).to eq(BigDecimal(0))
      expect(metrics[:top_accounts].first[:unrealized_pnl_quote]).to eq(BigDecimal("500.0"))
      expect(metrics[:top_accounts].first[:total_pnl_quote]).to eq(BigDecimal("500.0"))
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end

    it "returns nil top_accounts without totals when market prices are unavailable" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "positions_without_prices")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"}, output_dir: base_dir.to_s)
      File.write(
        File.join(base_dir, "checkpoint_6.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 6,
            "state" => {
              "accounts" => [
                {
                  "accountId" => "acc-1",
                  "markets" => [
                    {"marketId" => "BTC-USD", "quantity" => "0.5", "avgCost" => "59000"}
                  ]
                }
              ]
            }
          }
        )
      )

      metrics = described_class.new.call

      expect(metrics[:checkpoint_timeline_seq]).to eq(6)
      expect(metrics[:top_accounts]).to be_nil
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end

    it "derives realized net from persisted trade events when totals are absent" do
      base_dir = Rails.root.join("storage", "runs", "spec_live_state_metrics", "realized_from_events")
      FileUtils.mkdir_p(base_dir)

      run = Run.create!(
        status: :succeeded,
        input_json: {
          "schemaVersion" => "1.0",
          "priceSnapshot" => {
            "prices" => [
              {"marketId" => "BTC-USD", "priceQuotePerBase" => "95"}
            ]
          }
        },
        output_dir: base_dir.to_s
      )

      snapshot = RunSnapshot.create!(run: run, operational_date: Date.new(2026, 4, 17), reporting_currency: "USD")
      RunDailyEvent.create!(
        run_snapshot: snapshot,
        event_seq: 1,
        event_type: "TRADE_APPLIED",
        payload: {
          "eventType" => "TRADE_APPLIED",
          "trade" => {
            "accountId" => "acc-1",
            "marketId" => "BTC-USD",
            "side" => "BUY",
            "quantityBase" => "2",
            "priceQuotePerBase" => "100"
          }
        }
      )
      RunDailyEvent.create!(
        run_snapshot: snapshot,
        event_seq: 2,
        event_type: "TRADE_APPLIED",
        payload: {
          "eventType" => "TRADE_APPLIED",
          "trade" => {
            "accountId" => "acc-1",
            "marketId" => "BTC-USD",
            "side" => "SELL",
            "quantityBase" => "1",
            "priceQuotePerBase" => "110"
          }
        }
      )

      File.write(
        File.join(base_dir, "checkpoint_9.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 9,
            "state" => {
              "accounts" => [
                {
                  "accountId" => "acc-1",
                  "markets" => [
                    {"marketId" => "BTC-USD", "quantity" => "1", "avgCost" => "100"}
                  ]
                }
              ]
            }
          }
        )
      )

      metrics = described_class.new.call

      expect(metrics[:checkpoint_timeline_seq]).to eq(9)
      expect(metrics[:top_accounts]).to be_present
      top = metrics[:top_accounts].first
      expect(top[:account_id]).to eq("acc-1")
      expect(top[:realized_net_pnl_quote]).to eq(BigDecimal(10))
      expect(top[:unrealized_pnl_quote]).to eq(BigDecimal("-5"))
      expect(top[:total_pnl_quote]).to eq(BigDecimal(5))
    ensure
      run.destroy! if defined?(run) && run.persisted?
      FileUtils.rm_rf(base_dir) if defined?(base_dir)
    end
  end
end
