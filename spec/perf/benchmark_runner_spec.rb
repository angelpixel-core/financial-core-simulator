# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'
require 'json'

RSpec.describe 'Deterministic benchmark runner', :perf do
  let(:fixture_path) do
    File.expand_path('../../lib/fcs/fixtures/benchmark_fixture.json', __dir__)
  end

  it 'writes a benchmark report with deterministic metadata' do
    runner = FCS::Benchmarking::BenchmarkRunner.new(gate_seconds: 9_999.0)

    Dir.mktmpdir do |dir|
      result = runner.run!(
        fixture_path: fixture_path,
        output_dir: dir,
        runs: 1,
        command: 'spec bench'
      )

      report = result.fetch(:report)

      expect(File.exist?(result.fetch(:report_path))).to eq(true)
      expect(report.fetch('fixture_path')).to eq(fixture_path)
      expect(report.fetch('input_hash')).not_to be_nil
      expect(report.fetch('run_id')).not_to be_nil
      expect(report.fetch('p95_seconds')).to be_a(Float)
      expect(report.dig('artifacts', 'result_json')).to end_with('result.json')
      expect(report.dig('artifacts', 'positions_csv')).to end_with('positions.csv')
      expect(report.dig('artifacts', 'pnl_csv')).to end_with('pnl.csv')
    end
  end

  it 'produces the same input_hash and artifacts across runs' do
    runner = FCS::Benchmarking::BenchmarkRunner.new(gate_seconds: 9_999.0)

    first_dir = Dir.mktmpdir
    second_dir = Dir.mktmpdir

    first = runner.run!(
      fixture_path: fixture_path,
      output_dir: first_dir,
      runs: 1,
      command: 'spec bench'
    )

    second = runner.run!(
      fixture_path: fixture_path,
      output_dir: second_dir,
      runs: 1,
      command: 'spec bench'
    )

    first_report = first.fetch(:report)
    second_report = second.fetch(:report)

    expect(first_report.fetch('input_hash')).to eq(second_report.fetch('input_hash'))

    %w[result_json positions_csv pnl_csv].each do |key|
      first_path = first_report.dig('artifacts', key)
      second_path = second_report.dig('artifacts', key)

      expect(Digest::SHA256.file(first_path).hexdigest)
        .to eq(Digest::SHA256.file(second_path).hexdigest)
    end
  ensure
    FileUtils.remove_entry(first_dir) if first_dir
    FileUtils.remove_entry(second_dir) if second_dir
  end

  it 'fails when p95 exceeds the deterministic gate' do
    fake_runner = Class.new do
      def run_from_input!(input:, output_dir:, **_kwargs)
        FileUtils.mkdir_p(output_dir)
        json = File.join(output_dir, 'result.json')
        positions = File.join(output_dir, 'positions.csv')
        pnl = File.join(output_dir, 'pnl.csv')
        File.write(json, JSON.dump(input))
        File.write(positions, "account_id,market_id,quantity,avg_cost\n")
        File.write(pnl,
                   "account_id,market_id,realized_pnl_quote,fees_quote,realized_net_pnl_quote,unrealized_pnl_quote,total_pnl_quote,total_pnl_usd\n")

        {
          json_path: json,
          input_hash: 'hash-123',
          run_id: 'run-123',
          schema_version: input.fetch('schemaVersion'),
          valuation_timestamp: input.dig('priceSnapshot', 'valuationTimestamp'),
          artifacts: {
            json_path: json,
            positions_csv_path: positions,
            pnl_csv_path: pnl
          }
        }
      end
    end.new

    generator = instance_double(FCS::Benchmarking::InputGenerator)
    allow(generator).to receive(:generate).and_return({})

    runner = FCS::Benchmarking::BenchmarkRunner.new(
      generator: generator,
      runner: fake_runner,
      gate_seconds: 2.0
    )

    allow(Process).to receive(:clock_gettime).and_return(0.0, 2.5)

    Dir.mktmpdir do |dir|
      expect do
        runner.run!(
          fixture_path: fixture_path,
          output_dir: dir,
          runs: 1,
          command: 'spec bench'
        )
      end.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details.fetch('p95_gate_seconds')).to eq(2.0)
        expect(error.details.fetch('p95_seconds')).to be >= 2.0
      }
    end
  end
end
