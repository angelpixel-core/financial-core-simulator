# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::LedgerEngine do
  it "applies SELL and accumulates realizedPnL using avg cost" do
    engine = described_class.new

    buy = {
      "tradeId" => "b1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "3",
      "priceQuotePerBase" => "100"
    }

    sell = {
      "tradeId" => "s1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 2,
      "seq" => 1,
      "side" => "SELL",
      "quantityBase" => "2",
      "priceQuotePerBase" => "130"
    }

    engine.apply_trade!(buy)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")

    expect(pos.qty.to_s).to eq("1.0")
    expect(pos.avg_cost.to_s).to eq("100.0")
    # realized = (130 - 100) * 2 = 60
    expect(pos.realized_pnl_quote.to_s).to eq("60.0")
  end

  it "rejects SELL when sell quantity exceeds available long position" do
    engine = described_class.new

    buy = {
      "tradeId" => "b1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "1",
      "priceQuotePerBase" => "100"
    }

    sell = {
      "tradeId" => "s1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 2,
      "seq" => 1,
      "side" => "SELL",
      "quantityBase" => "2",
      "priceQuotePerBase" => "110"
    }

    engine.apply_trade!(buy)

    expect { engine.apply_trade!(sell) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE)
        expect(e.details).to include(
          accountId: "acc-1",
          marketId: "ETH-USD",
          qty: "1.0",
          sellQty: "2.0"
        )
      }
  end

  it "resets avg_cost to 0 when position is fully closed" do
    engine = described_class.new

    buy = {
      "tradeId" => "b1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 1,
      "seq" => 1,
      "side" => "BUY",
      "quantityBase" => "2",
      "priceQuotePerBase" => "100"
    }

    sell = {
      "tradeId" => "s1",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => 2,
      "seq" => 1,
      "side" => "SELL",
      "quantityBase" => "2",
      "priceQuotePerBase" => "90"
    }

    engine.apply_trade!(buy)
    engine.apply_trade!(sell)

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    expect(pos.qty.to_s).to eq("0.0")
    expect(pos.avg_cost.to_s).to eq("0.0")
  end

  it "keeps avg_cost unchanged after a partial SELL" do
    engine = described_class.new

    engine.apply_trade!(
      {
        "tradeId" => "b1",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => "1",
        "priceQuotePerBase" => "100"
      }
    )

    engine.apply_trade!(
      {
        "tradeId" => "b2",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 2,
        "seq" => 2,
        "side" => "BUY",
        "quantityBase" => "1",
        "priceQuotePerBase" => "140"
      }
    )

    before_sell = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD").avg_cost.to_s

    engine.apply_trade!(
      {
        "tradeId" => "s1",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 3,
        "seq" => 3,
        "side" => "SELL",
        "quantityBase" => "1",
        "priceQuotePerBase" => "130"
      }
    )

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    expect(pos.avg_cost.to_s).to eq(before_sell)
    expect(pos.realized_pnl_quote.to_s).to eq("10.0")
  end

  it "handles deterministic decimal precision for average-cost updates" do
    engine = described_class.new

    engine.apply_trade!(
      {
        "tradeId" => "b1",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 1,
        "seq" => 1,
        "side" => "BUY",
        "quantityBase" => "0.1",
        "priceQuotePerBase" => "1234.567890123456789"
      }
    )

    engine.apply_trade!(
      {
        "tradeId" => "b2",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 2,
        "seq" => 2,
        "side" => "BUY",
        "quantityBase" => "0.2",
        "priceQuotePerBase" => "1234.567890123456781"
      }
    )

    engine.apply_trade!(
      {
        "tradeId" => "s1",
        "accountId" => "acc-1",
        "marketId" => "ETH-USD",
        "timestamp" => 3,
        "seq" => 3,
        "side" => "SELL",
        "quantityBase" => "0.3",
        "priceQuotePerBase" => "1234.567890123456790"
      }
    )

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    expect(pos.qty.to_s).to eq("0.0")
    expect(pos.avg_cost.to_s).to eq("0.0")
    expect(pos.realized_pnl_quote.to_s).to eq("0.0000000000000019")
  end
end
