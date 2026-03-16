# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"

RSpec.describe FCS::Benchmarking::BenchmarkRunner do
  let(:generator) { instance_double(FCS::Benchmarking::InputGenerator) }
  let(:runner) { instance_double(FCS::Application::Runner) }
  let(:logger) { instance_double(FCS::Logging::SimpleLogger, info: nil) }
  let(:clock) { class_double(Time, now: Time.parse("2026-02-25T03:00:00Z")) }

  def base_fixture
    instance_double(
      FCS::Benchmarking::Fixture,
      trades: 2,
      accounts: 1,
      markets: 1,
      schema_version: "1.0",
      valuation_timestamp: "2026-02-25T03:00:00Z",
      to_h: { "schema_version" => "1.0" }
    )
  end

  it "normalizes runs to default when invalid" do
    runner = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock)

    expect(runner.send(:normalize_runs, 0)).to eq(described_class::DEFAULT_RUNS)
    expect(runner.send(:normalize_runs, -1)).to eq(described_class::DEFAULT_RUNS)
    expect(runner.send(:normalize_runs, 3)).to eq(3)
  end

  it "tracks metadata and raises on drift" do
    runner = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock)

    base = { input_hash: "a", run_id: "b" }
    candidate = { input_hash: "a", run_id: "b" }
    expect(runner.send(:track_metadata!, base, candidate, "fixture.json")).to eq(base)

    expect do
      runner.send(:track_metadata!, base, { input_hash: "x", run_id: "b" }, "fixture.json")
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
  end

  it "calculates percentile from sorted timings" do
    runner = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock)
    expect(runner.send(:percentile, [1.0, 2.0, 3.0, 4.0], 0.95)).to eq(4.0)
  end

  it "enforces p95 gate and raises with details" do
    runner = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock, gate_seconds: 1.0)

    report = { "p95_seconds" => 2.0 }

    expect do
      runner.send(:enforce_p95_gate!, report: report, report_path: "out/report.json", fixture_path: "fx.json",
                                      command: "run")
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
  end

  it "writes deterministic report with canonical json" do
    Dir.mktmpdir do |dir|
      runner = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock)
      completed_at = Time.parse("2026-02-25T03:00:00Z")

      report = { "report_schema_version" => "1.0" }
      path = runner.send(:write_report, output_dir: dir, report: report, completed_at: completed_at)

      expect(path).to include("benchmark_report_20260225T030000Z")
      expect(File.read(path)).to include("report_schema_version")
    end
  end

  it "runs the benchmark and produces report metadata" do
    fixture = base_fixture

    allow(FCS::Benchmarking::Fixture).to receive(:load).and_return(fixture)
    allow(generator).to receive(:generate).and_return(
      { "priceSnapshot" => {}, "accounts" => [], "markets" => [], "trades" => [] }
    )

    allow(runner).to receive(:run_from_input!).and_return(
      {
        input_hash: "hash",
        run_id: "run-id",
        artifacts: { json_path: "out/result.json", positions_csv_path: "out/positions.csv",
                     pnl_csv_path: "out/pnl.csv" }
      }
    )

    benchmark = described_class.new(generator: generator, runner: runner, logger: logger, clock: clock,
                                    gate_seconds: 100)

    Dir.mktmpdir do |dir|
      result = benchmark.run!(fixture_path: "fixture.json", output_dir: dir, runs: 1, command: "bench")

      expect(result.fetch(:report)).to include(
        "runs" => 1,
        "fixture_path" => "fixture.json",
        "input_hash" => "hash",
        "run_id" => "run-id",
        "artifacts" => include("result_json" => "out/result.json")
      )
      expect(File).to exist(result.fetch(:report_path))
    end
  end
end
