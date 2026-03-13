# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'

RSpec.describe 'Deterministic benchmark runner', :perf do
  let(:fixture_path) do
    File.expand_path('../../lib/fcs/fixtures/benchmark_fixture.json', __dir__)
  end

  it 'writes a benchmark report with deterministic metadata' do
    runner = FCS::Benchmarking::BenchmarkRunner.new

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
    runner = FCS::Benchmarking::BenchmarkRunner.new

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
end
