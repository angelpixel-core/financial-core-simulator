# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::EventTimelineProcessor do
  def d18(value)
    FCS::Types::Decimal18.from_string(value)
  end

  it "processes events in timeline order and writes checkpoints" do
    ledger_state = instance_spy("LedgerState", positions: {})
    ledger = instance_spy("Ledger", state: ledger_state)
    valuation = instance_spy("Valuation")
    checkpoint_store = instance_spy("CheckpointStore")

    events = [
      {
        "eventType" => "TRADE_APPLIED",
        "timelineSeq" => 2,
        "trade" => {
          "tradeId" => "t-1",
          "accountId" => "acc-1",
          "marketId" => "ETH-USD",
          "seq" => 1,
          "side" => "BUY",
          "quantityBase" => "1",
          "priceQuotePerBase" => "100"
        }
      },
      {
        "eventType" => "PRICE_UPDATED",
        "timelineSeq" => 1,
        "marketId" => "ETH-USD",
        "priceQuotePerBase" => "110"
      }
    ]

    described_class.new.call(
      events: events,
      ledger: ledger,
      valuation: valuation,
      checkpoint_store: checkpoint_store,
      input_hash: "hash-1"
    )

    expect(valuation).to have_received(:update_price!).with(
      market_id: "ETH-USD",
      price_quote_per_base: "110"
    )
    expect(ledger).to have_received(:apply_trade!).with(
      "tradeId" => "t-1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "1",
      "priceQuotePerBase" => "100"
    )
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 1,
      timeline_seq: 1,
      state: { "accounts" => [] },
      input_hash: "hash-1"
    )
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 2,
      timeline_seq: 2,
      state: { "accounts" => [] },
      input_hash: "hash-1"
    )
  end

  it "skips events at or before checkpoint sequence" do
    position = instance_spy("Position")
    ledger_state = instance_spy("LedgerState")
    allow(ledger_state).to receive(:position_for)
      .with(account_id: "acc-1", market_id: "ETH-USD")
      .and_return(position)

    ledger = instance_spy("Ledger", state: ledger_state)
    valuation = instance_spy("Valuation")

    checkpoint = {
      "timelineSeq" => 2,
      "state" => {
        "accounts" => [
          {
            "accountId" => "acc-1",
            "markets" => [
              { "marketId" => "ETH-USD", "quantity" => "1", "avgCost" => "100" }
            ]
          }
        ]
      }
    }

    events = [
      { "eventType" => "TRADE_APPLIED", "timelineSeq" => 1, "trade" => {} },
      { "eventType" => "TRADE_APPLIED", "timelineSeq" => 2, "trade" => {} },
      { "eventType" => "PRICE_UPDATED", "timelineSeq" => 3, "marketId" => "ETH-USD", "priceQuotePerBase" => "120" }
    ]

    described_class.new.call(
      events: events,
      ledger: ledger,
      valuation: valuation,
      checkpoint: checkpoint
    )

    expect(position).to have_received(:apply_buy!).with(
      buy_qty: have_attributes(atoms: d18("1").atoms),
      buy_price: have_attributes(atoms: d18("100").atoms)
    )
    expect(valuation).to have_received(:update_price!).with(market_id: "ETH-USD", price_quote_per_base: "120")
    expect(ledger).not_to have_received(:apply_trade!)
  end

  it "captures sorted account and market positions for checkpoints" do
    positions = {
      "acc-2|ETH-USD" => instance_spy("Position", qty: d18("1"), avg_cost: d18("100")),
      "acc-1|BTC-USD" => instance_spy("Position", qty: d18("2"), avg_cost: d18("90")),
      "acc-1|ETH-USD" => instance_spy("Position", qty: d18("3"), avg_cost: d18("80"))
    }

    ledger_state = instance_spy("LedgerState", positions: positions)
    ledger = instance_spy("Ledger", state: ledger_state)
    valuation = instance_spy("Valuation")
    checkpoint_store = instance_spy("CheckpointStore")

    described_class.new.call(
      events: [
        { "eventType" => "PRICE_UPDATED", "timelineSeq" => 1, "marketId" => "ETH-USD", "priceQuotePerBase" => "110" }
      ],
      ledger: ledger,
      valuation: valuation,
      checkpoint_store: checkpoint_store
    )

    expect(valuation).to have_received(:update_price!).with(market_id: "ETH-USD", price_quote_per_base: "110")
    expect(checkpoint_store).to have_received(:write_if_due!).with(
      event_count: 1,
      timeline_seq: 1,
      state: {
        "accounts" => [
          {
            "accountId" => "acc-1",
            "markets" => [
              { "marketId" => "BTC-USD", "quantity" => "2.0", "avgCost" => "90.0" },
              { "marketId" => "ETH-USD", "quantity" => "3.0", "avgCost" => "80.0" }
            ]
          },
          {
            "accountId" => "acc-2",
            "markets" => [
              { "marketId" => "ETH-USD", "quantity" => "1.0", "avgCost" => "100.0" }
            ]
          }
        ]
      },
      input_hash: ""
    )
  end
end
