# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"

module Runs
  class Execute
    def call(run, fee_enabled: true, explain: true, verbose: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      run.update!(status: :running, error_code: nil, error_message: nil)

      Runs::ApplyFxContext.call(run: run)

      output_dir = ensure_output_dir(run)

      input = run.input_json
      raise "Run#input_json is required" if input.blank?

      runner = FCS::Application::Runner.new
      result = runner.run_from_input!(
        input: input,
        output_dir: output_dir,
        fee_enabled: fee_enabled,
        explain: explain,
        verbose: verbose
      )

      json_path = result.fetch(:json_path)
      annotated_input = result.fetch(:annotated_input)
      validation_errors = result.fetch(:validation_errors)
      reliable = result.fetch(:reliable)

      write_input_json(annotated_input, output_dir)

      payload = JSON.parse(File.read(json_path))
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      run.update!(
        status: :succeeded,
        engine_version: payload["engineVersion"],
        schema_version: payload["schemaVersion"],
        run_uuid: payload["runId"],
        input_hash: payload["inputHash"],
        input_json: annotated_input,
        valuation_timestamp: payload["valuationTimestamp"],
        output_dir: output_dir,
        reliable: reliable,
        artifacts: {
          "result_json_path" => json_path,
          "positions_csv_path" => File.join(output_dir, "positions.csv"),
          "pnl_csv_path" => File.join(output_dir, "pnl.csv")
        },
        duration_ms: duration_ms
      )

      persist_validation_errors(run, validation_errors, annotated_input)

      Runs::PersistDailyArtifacts.call(run: run)
      Admin::Fx::RunRateGapProcessor.call(run: run)

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

    def write_input_json(input, output_dir)
      raise "Run#input_json is required" if input.blank?

      path = File.join(output_dir, "input.json")
      File.write(path, JSON.pretty_generate(input) + "\n")
      path
    end

    def persist_validation_errors(run, validation_errors, input)
      run.run_validation_errors.delete_all
      return if validation_errors.blank?

      correlation_id = input.is_a?(Hash) ? (input["correlationId"] || run.run_uuid) : run.run_uuid
      now = Time.current

      entries = validation_errors.map do |error|
        {
          run_id: run.id,
          source: error[:source],
          field: error[:field],
          message: error[:message].to_s,
          code: error[:code],
          trade_id: error[:trade_id],
          account_id: error[:account_id],
          market_id: error[:market_id],
          timeline_seq: error[:timeline_seq],
          event_type: error[:event_type],
          row_index: error[:row_index],
          occurred_at: parse_occurred_at(error[:occurred_at]),
          correlation_id: correlation_id,
          created_at: now,
          updated_at: now
        }
      end

      RunValidationError.insert_all(entries)
    end

    def parse_occurred_at(value)
      return nil if value.blank?
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
