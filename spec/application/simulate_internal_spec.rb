# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::Simulate do
  def d18(value)
    FCS::Types::Decimal18.from_string(value)
  end

  it "uses timeline processor when timeline events are provided" do
    ledger = instance_double("Ledger")
    valuation = instance_double("Valuation")
    timeline_processor = instance_double("TimelineProcessor")

    input = { "timeline" => { "events" => [{ "timelineSeq" => 1 }] } }

    expect(timeline_processor).to receive(:call).with(
      events: input.fetch("timeline").fetch("events"),
      ledger: ledger,
      valuation: valuation,
      checkpoint: nil,
      checkpoint_store: nil,
      input_hash: nil
    )

    described_class.new.send(
      :apply_execution_flow!,
      input: input,
      ledger: ledger,
      valuation: valuation,
      timeline_processor: timeline_processor,
      checkpoint_store: nil,
      input_hash: nil
    )
  end

  it "applies deterministic batch trades when no timeline is provided" do
    ledger = instance_double("Ledger")
    valuation = instance_double("Valuation")
    timeline_processor = instance_double("TimelineProcessor")

    trades = [
      { "tradeId" => "t-2", "timestamp" => 2, "seq" => 2 },
      { "tradeId" => "t-1", "timestamp" => 1, "seq" => 1 }
    ]

    input = { "trades" => trades }

    expect(ledger).to receive(:apply_trade!).with(trades[1])
    expect(ledger).to receive(:apply_trade!).with(trades[0])

    described_class.new.send(
      :apply_execution_flow!,
      input: input,
      ledger: ledger,
      valuation: valuation,
      timeline_processor: timeline_processor,
      checkpoint_store: nil,
      input_hash: nil
    )
  end

  it "sums market fields and includes USD totals when enabled" do
    fx = instance_double("FX", enabled?: true)
    expect(fx).to receive(:quote_to_usd)
      .with(have_attributes(atoms: d18("6").atoms))
      .and_return(d18("12"))

    markets = [
      {
        "realizedPnLQuote" => "1",
        "feesQuote" => "0.5",
        "realizedNetPnLQuote" => "0.5",
        "unrealizedPnLQuote" => "2",
        "totalPnLQuote" => "2.5"
      },
      {
        "realizedPnLQuote" => "2",
        "feesQuote" => "0.5",
        "realizedNetPnLQuote" => "1.5",
        "unrealizedPnLQuote" => "1",
        "totalPnLQuote" => "3.5"
      }
    ]

    totals = described_class.new.send(:sum_market_fields, markets, fx)

    expect(totals).to include(
      "realizedPnLQuote" => "3.0",
      "feesQuote" => "1.0",
      "realizedNetPnLQuote" => "2.0",
      "unrealizedPnLQuote" => "3.0",
      "totalPnLQuote" => "6.0",
      "totalPnLUsd" => "12.0"
    )
  end

  it "consolidates global totals across accounts" do
    fx = instance_double("FX", enabled?: false)
    accounts = [
      { "totals" => { "realizedPnLQuote" => "1", "feesQuote" => "0", "realizedNetPnLQuote" => "1",
                      "unrealizedPnLQuote" => "2", "totalPnLQuote" => "3" } },
      { "totals" => { "realizedPnLQuote" => "2", "feesQuote" => "1", "realizedNetPnLQuote" => "1",
                      "unrealizedPnLQuote" => "1", "totalPnLQuote" => "2" } }
    ]

    totals = described_class.new.send(:consolidate_global, accounts, fx)

    expect(totals).to include(
      "realizedPnLQuote" => "3.0",
      "feesQuote" => "1.0",
      "realizedNetPnLQuote" => "2.0",
      "unrealizedPnLQuote" => "3.0",
      "totalPnLQuote" => "5.0",
      "totalPnLUsd" => nil
    )
  end

  it "extracts account collateral when provided" do
    input = {
      "accounts" => [
        { "accountId" => "acc-1", "collateralQuote" => "10" },
        { "accountId" => "acc-2" }
      ]
    }

    result = described_class.new.send(:extract_account_collateral, input)

    expect(result.fetch("acc-1").to_s).to eq("10.0")
    expect(result).not_to have_key("acc-2")
  end

  it "extracts risk configuration with defaults" do
    input = {
      "riskModel" => {
        "maxLeverage" => "5",
        "maintenanceMarginRatio" => "0.5",
        "liquidation" => { "closeFactor" => "0.3" }
      }
    }

    result = described_class.new.send(:extract_risk_config, input)

    expect(result.fetch(:maxLeverage).to_s).to eq("5.0")
    expect(result.fetch(:maintenanceMarginRatio).to_s).to eq("0.5")
    expect(result.fetch(:liquidation)).to eq(enabled: true, closeFactor: "0.3")
  end

  it "indexes risk events by account" do
    candidates = [
      { account_id: "acc-1", market_id: "ETH-USD", seq: 1, severity: d18("0.9") },
      { account_id: "acc-2", market_id: "BTC-USD", seq: 2, severity: d18("0.7") }
    ]

    result = described_class.new.send(:index_risk_events, candidates)

    expect(result.fetch("acc-1").first).to include(
      "type" => "RISK_LIQUIDATION_CANDIDATE",
      "reasonCode" => FCS::Errors::ERR_RISK_LIQUIDATABLE,
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "seq" => 1,
      "severity" => "0.9"
    )
  end

  it "detects USD conversion based on model or fx quote" do
    with_model = { "usdModel" => { "enabled" => true } }
    with_fx = { "priceSnapshot" => { "fx" => { "quoteUsd" => "1.0" } } }
    without = { "priceSnapshot" => { "fx" => {} } }

    simulator = described_class.new

    expect(simulator.send(:usd_conversion_enabled?, with_model)).to be(true)
    expect(simulator.send(:usd_conversion_enabled?, with_fx)).to be(true)
    expect(simulator.send(:usd_conversion_enabled?, without)).to be(false)
  end

  it "builds market payload with explain data when requested" do
    position = instance_double(
      "Position",
      qty: d18("2"),
      avg_cost: d18("100"),
      realized_pnl_quote: d18("0"),
      fees_quote: d18("1"),
      realized_net_quote: d18("-1")
    )
    valuation = instance_double("Valuation")
    fx = instance_double("FX", enabled?: false)

    expect(valuation).to receive(:unrealized_pnl_quote).and_return(d18("5"))
    expect(valuation).to receive(:snapshot_price_for).and_return(d18("110"))

    payload = described_class.new.send(:build_market_payload, "ETH-USD", position, valuation, fx, true)

    expect(payload.fetch("explain")).to include(
      "snapshotPrice" => "110.0",
      "avgCost" => "100.0",
      "qty" => "2.0",
      "realizedPnLQuote" => "0.0",
      "feesQuote" => "1.0",
      "unrealizedPnLQuote" => "5.0",
      "totalPnLQuote" => "4.0"
    )
  end
end
