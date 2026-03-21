# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"

module Runs
  class Execute
    def call(run, fee_enabled: true, explain: true, verbose: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      run.update!(status: :running, error_code: nil, error_message: nil)

      output_dir = ensure_output_dir(run)
      input_path = write_input_json(run, output_dir)

      runner = FCS::Application::Runner.new
      json_path = runner.run!(
        input_path: input_path,
        output_dir: output_dir,
        fee_enabled: fee_enabled,
        explain: explain,
        verbose: verbose
      )

      payload = JSON.parse(File.read(json_path))
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      run.update!(
        status: :succeeded,
        engine_version: payload["engineVersion"],
        schema_version: payload["schemaVersion"],
        run_uuid: payload["runId"],
        input_hash: payload["inputHash"],
        valuation_timestamp: payload["valuationTimestamp"],
        output_dir: output_dir,
        artifacts: {
          "result_json_path" => json_path,
          "positions_csv_path" => File.join(output_dir, "positions.csv"),
          "pnl_csv_path" => File.join(output_dir, "pnl.csv")
        },
        duration_ms: duration_ms
      )

      run
    rescue => e
      duration_ms = begin
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      rescue
        nil
      end
      run.update!(
        status: :failed,
        duration_ms: duration_ms,
        error_code: Runs::ErrorCodeMapper.call(e),
        error_message: e.message
      )
      raise
    end

    private

    def ensure_output_dir(run)
      base = Rails.root.join("storage", "runs")
      FileUtils.mkdir_p(base)

      dir = base.join("run_#{run.id}_#{Time.now.utc.strftime("%Y%m%dT%H%M%S")}")
      FileUtils.mkdir_p(dir)
      dir.to_s
    end

    def write_input_json(run, output_dir)
      input = run.input_json
      raise "Run#input_json is required" if input.blank?

      path = File.join(output_dir, "input.json")
      File.write(path, JSON.pretty_generate(input) + "\n")
      path
    end
  end
end
