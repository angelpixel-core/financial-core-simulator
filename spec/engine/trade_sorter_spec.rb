# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Engine::TradeSorter do
  subject(:sorter) { described_class.new }

  it "orders by timestamp then seq" do
    trades = [
      { "tradeId" => "t3", "timestamp" => 10, "seq" => 2 },
      { "tradeId" => "t1", "timestamp" => 5,  "seq" => 2 },
      { "tradeId" => "t2", "timestamp" => 5,  "seq" => 1 },
      { "tradeId" => "t4", "timestamp" => 10, "seq" => 1 }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"] }
    expect(sorted).to eq(%w[t2 t1 t4 t3])
  end

  it "keeps deterministic order when timestamp and seq are tied" do
    trades = [
      { "tradeId" => "t-b", "timestamp" => 5, "seq" => 1, "accountId" => "acc-2", "marketId" => "BTC-USD" },
      { "tradeId" => "t-a", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" },
      { "tradeId" => "t-c", "timestamp" => 5, "seq" => 1, "accountId" => "acc-2", "marketId" => "ETH-USD" }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"] }
    expect(sorted).to eq(%w[t-a t-b t-c])
  end

  it "uses tradeId as final tie-breaker when all prior keys match" do
    trades = [
      { "tradeId" => "t-z", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" },
      { "tradeId" => "t-a", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" },
      { "tradeId" => "t-m", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"] }
    expect(sorted).to eq(%w[t-a t-m t-z])
  end
end
