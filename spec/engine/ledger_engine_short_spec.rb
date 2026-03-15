require_relative "../../lib/fcs"

RSpec.describe "LedgerEngine long-only enforcement" do
  let(:collateral) { { "acc-1" => FCS::Types::Decimal18.from_string("100") } }
  let(:max_leverage) { FCS::Types::Decimal18.from_string("2") }

  def sell_trade(qty:, price:, seq: 1)
    {
      "tradeId" => "s#{seq}",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => seq,
      "seq" => seq,
      "side" => "SELL",
      "quantityBase" => qty,
      "priceQuotePerBase" => price
    }
  end

  def buy_trade(qty:, price:, seq: 99)
    {
      "tradeId" => "b#{seq}",
      "accountId" => "acc-1",
      "marketId" => "ETH-USD",
      "timestamp" => seq,
      "seq" => seq,
      "side" => "BUY",
      "quantityBase" => qty,
      "priceQuotePerBase" => price
    }
  end

  it "rejects opening a short even when leverage config exists" do
    engine = FCS::Engine::LedgerEngine.new(
      account_collateral: collateral,
      max_leverage: max_leverage
    )

    expect { engine.apply_trade!(sell_trade(qty: "1", price: "100", seq: 1)) }
      .to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end

  it "rejects short when collateral or max leverage is missing" do
    engine = FCS::Engine::LedgerEngine.new

    expect { engine.apply_trade!(sell_trade(qty: "1", price: "100")) }
      .to raise_error(FCS::Error) { |e| expect(e.code).to eq(FCS::Errors::ERR_POSITION_NEGATIVE) }
  end

  it "allows sell when quantity exactly matches current long position" do
    engine = FCS::Engine::LedgerEngine.new(
      account_collateral: collateral,
      max_leverage: max_leverage
    )

    engine.apply_trade!(buy_trade(qty: "1", price: "100", seq: 1))
    expect { engine.apply_trade!(sell_trade(qty: "1", price: "110", seq: 2)) }.not_to raise_error

    pos = engine.state.position_for(account_id: "acc-1", market_id: "ETH-USD")
    expect(pos.qty.to_s).to eq("0.0")
    expect(pos.avg_cost.to_s).to eq("0.0")
  end
end
