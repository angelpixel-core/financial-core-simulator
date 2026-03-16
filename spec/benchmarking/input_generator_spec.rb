# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Benchmarking::InputGenerator do
  it "generates deterministic input structure" do
    generator = described_class.new

    input = generator.generate(trades: 3, accounts: 2, markets: 1)

    expect(input).to include(
      "schemaVersion" => "1.0",
      "feeModel" => { "enabled" => true }
    )
    expect(input.fetch("accounts").map { |a| a.fetch("accountId") }).to eq(%w[acc-1 acc-2])
    expect(input.fetch("markets").map { |m| m.fetch("marketId") }).to eq(["MKT-1"])
    expect(input.fetch("trades").size).to eq(3)
    expect(input.dig("priceSnapshot", "prices").size).to eq(1)
  end

  it "keeps trades long-only safe with sequential ids" do
    generator = described_class.new

    trades = generator.generate(trades: 6, accounts: 1, markets: 1).fetch("trades")

    expect(trades.map { |t| t.fetch("tradeId") }).to eq(%w[t-1 t-2 t-3 t-4 t-5 t-6])
    expect(trades.map { |t| t.fetch("quantityBase") }.uniq).to eq(["1"])
    expect(trades.map { |t| t.fetch("seq") }.min).to eq(1)
    expect(trades.all? { |t| %w[BUY SELL].include?(t.fetch("side")) }).to be(true)
  end
end
