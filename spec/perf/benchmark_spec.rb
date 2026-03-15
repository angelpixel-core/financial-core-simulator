# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Performance benchmark", :perf do
  it "processes 100k trades under 2 seconds (local target)" do
    input = FCS::Benchmarking::InputGenerator.new.generate(trades: 100_000, accounts: 10, markets: 5)
    simulate = FCS::Application::Simulate.new

    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    simulate.call(input)
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect(t1 - t0).to be < 2.0
  end

  it "processes 100k trades under 2.2 seconds with risk model enabled" do
    input = FCS::Benchmarking::InputGenerator.new.generate(trades: 100_000, accounts: 10, markets: 5)
    input["accounts"].each { |acc| acc["collateralQuote"] = "100000" }
    input["riskModel"] = {
      "maxLeverage" => "50",
      "maintenanceMarginRatio" => "0.25",
      "liquidation" => { "enabled" => true, "closeFactor" => "0.5" }
    }

    simulate = FCS::Application::Simulate.new

    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    simulate.call(input)
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect(t1 - t0).to be < 2.2
  end
end
