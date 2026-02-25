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
end
