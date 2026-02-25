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
end
