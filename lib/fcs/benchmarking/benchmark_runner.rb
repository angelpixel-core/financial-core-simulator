# frozen_string_literal: true

require 'fileutils'
require 'time'

module FCS
  module Benchmarking
    class BenchmarkRunner
      DEFAULT_RUNS = 5
      P95_GATE_SECONDS = 2.0

      def initialize(
        generator: FCS::Benchmarking::InputGenerator.new,
        runner: FCS::Application::Runner.new,
        logger: FCS.logger,
        clock: Time,
        gate_seconds: P95_GATE_SECONDS
      )
        @generator = generator
        @runner = runner
        @logger = logger
        @clock = clock
        @gate_seconds = gate_seconds
      end

      def run!(fixture_path:, output_dir:, runs:, command:)
        fixture = FCS::Benchmarking::Fixture.load(path: fixture_path)
        run_count = normalize_runs(runs)

        input = @generator.generate(
          trades: fixture.trades,
          accounts: fixture.accounts,
          markets: fixture.markets
        )

        input['schemaVersion'] = fixture.schema_version
        input['priceSnapshot'] ||= {}
        input['priceSnapshot']['valuationTimestamp'] = fixture.valuation_timestamp

        FileUtils.mkdir_p(output_dir)
        artifacts_dir = File.join(output_dir, 'artifacts')
        FileUtils.mkdir_p(artifacts_dir)

        started_at = @clock.now.utc
        timings = []
        metadata = nil

        run_count.times do
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          run_metadata = @runner.run_from_input!(
            input: input,
            output_dir: artifacts_dir,
            fee_enabled: true,
            explain: false,
            verbose: false,
            input_source: fixture_path
          )
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          timings << (t1 - t0)
          metadata = track_metadata!(metadata, run_metadata, fixture_path)
        end

        completed_at = @clock.now.utc

        report = build_report(
          command: command,
          fixture_path: fixture_path,
          fixture: fixture,
          timings: timings,
          started_at: started_at,
          completed_at: completed_at,
          metadata: metadata
        )

        report_path = write_report(output_dir: output_dir, report: report, completed_at: completed_at)

        enforce_p95_gate!(report: report, report_path: report_path, fixture_path: fixture_path, command: command)

        { report_path: report_path, report: report }
      end

      private

      def normalize_runs(runs)
        value = runs.to_i
        return DEFAULT_RUNS if value <= 0

        value
      end

      def track_metadata!(base, candidate, fixture_path)
        return candidate if base.nil?

        if base.fetch(:input_hash) != candidate.fetch(:input_hash) || base.fetch(:run_id) != candidate.fetch(:run_id)
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'Benchmark input hash drift detected',
            details: {
              fixture: fixture_path,
              base_input_hash: base.fetch(:input_hash),
              candidate_input_hash: candidate.fetch(:input_hash),
              base_run_id: base.fetch(:run_id),
              candidate_run_id: candidate.fetch(:run_id)
            }
          )
        end

        base
      end

      def build_report(command:, fixture_path:, fixture:, timings:, started_at:, completed_at:, metadata:)
        {
          'report_schema_version' => '1.0',
          'command' => command,
          'fixture_path' => fixture_path,
          'fixture' => fixture.to_h,
          'runs' => timings.length,
          'started_at' => started_at.iso8601,
          'completed_at' => completed_at.iso8601,
          'timings_seconds' => timings,
          'p95_seconds' => percentile(timings, 0.95),
          'p95_gate_seconds' => @gate_seconds,
          'input_hash' => metadata.fetch(:input_hash),
          'run_id' => metadata.fetch(:run_id),
          'engine_version' => FCS::VERSION,
          'artifacts' => {
            'result_json' => metadata.fetch(:artifacts).fetch(:json_path),
            'positions_csv' => metadata.fetch(:artifacts).fetch(:positions_csv_path),
            'pnl_csv' => metadata.fetch(:artifacts).fetch(:pnl_csv_path)
          }
        }
      end

      def percentile(values, percentile)
        sorted = values.sort
        index = (percentile * (sorted.length - 1)).ceil
        sorted[index]
      end

      def enforce_p95_gate!(report:, report_path:, fixture_path:, command:)
        p95 = report.fetch('p95_seconds')
        return if p95 < @gate_seconds

        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          'Benchmark p95 exceeded deterministic gate',
          details: {
            'p95_seconds' => p95,
            'p95_gate_seconds' => @gate_seconds,
            'report_path' => report_path,
            'fixture_path' => fixture_path,
            'command' => command
          }
        )
      end

      def write_report(output_dir:, report:, completed_at:)
        timestamp = completed_at.iso8601.gsub(':', '').gsub('-', '')
        path = File.join(output_dir, "benchmark_report_#{timestamp}.json")
        payload = FCS::Hashing::CanonicalJSON.dump(report)
        File.write(path, payload + "\n")
        path
      end
    end
  end
end
