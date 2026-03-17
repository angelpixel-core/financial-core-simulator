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

  it "orders by marketId before tradeId when timestamp, seq, and accountId match" do
    trades = [
      { "tradeId" => "t-a", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "Z-USD" },
      { "tradeId" => "t-z", "timestamp" => 5, "seq" => 1, "accountId" => "acc-1", "marketId" => "A-USD" }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"] }
    expect(sorted).to eq(%w[t-z t-a])
  end

  it "coerces ids to strings for deterministic ordering" do
    trades = [
      { "tradeId" => 2, "timestamp" => 1, "seq" => 1, "accountId" => nil, "marketId" => nil },
      { "tradeId" => 1, "timestamp" => 1, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"].to_s }

    expect(sorted).to eq(%w[2 1])
  end

  it "sorts even when ids are nil" do
    trades = [
      { "tradeId" => nil, "timestamp" => 1, "seq" => 1, "accountId" => nil, "marketId" => nil },
      { "tradeId" => "a", "timestamp" => 1, "seq" => 1, "accountId" => "", "marketId" => "" }
    ]

    sorted = sorter.sort(trades).map { |t| t["tradeId"].to_s }

    expect(sorted).to eq(["", "a"])
  end

  it "does not require tradeId key to exist" do
    trades = [
      { "timestamp" => 1, "seq" => 1, "accountId" => "acc-1", "marketId" => "ETH-USD" },
      { "timestamp" => 1, "seq" => 2, "accountId" => "acc-1", "marketId" => "ETH-USD", "tradeId" => "t-1" }
    ]

    expect { sorter.sort(trades) }.not_to raise_error
  end
end
