# frozen_string_literal: true

module FCS
  module Reporting
    class CliSummary
      REQUIRED_ARTIFACT_KEYS = [
        [:json_path, "result_json"],
        [:positions_csv_path, "positions_csv"],
        [:pnl_csv_path, "pnl_csv"]
      ].freeze

      def initialize(io: $stdout)
        @io = io
      end

      def print(result_json_payload, artifacts: {}, status: "success", validate_artifacts: true)
        validate_artifacts!(artifacts) if validate_artifacts

        lines = []
        lines << "=== fcs_summary ==="
        lines << "status: #{status}"
        lines << "run_id: #{result_json_payload.fetch('runId')}"
        lines << "input_hash: #{result_json_payload.fetch('inputHash')}"
        lines << "schema_version: #{result_json_payload.fetch('schemaVersion')}"
        lines << "engine_version: #{result_json_payload.fetch('engineVersion')}"
        lines << "valuation_timestamp: #{result_json_payload.fetch('valuationTimestamp')}"
        lines.concat(metric_lines(result_json_payload.fetch("global")))
        lines.concat(artifact_lines(artifacts))

        @io.puts(lines.join("\n"))
      end

      private

      def metric_lines(global)
        lines = []
        lines << "metrics:"
        lines << "  realized_pnl_quote: #{format_value(global.fetch('realizedPnLQuote'))}"
        lines << "  fees_quote: #{format_value(global.fetch('feesQuote'))}"
        lines << "  realized_net_pnl_quote: #{format_value(global.fetch('realizedNetPnLQuote'))}"
        lines << "  unrealized_pnl_quote: #{format_value(global.fetch('unrealizedPnLQuote'))}"
        lines << "  total_pnl_quote: #{format_value(global.fetch('totalPnLQuote'))}"
        lines << "  total_pnl_usd: #{format_value(global['totalPnLUsd'])}"
        lines
      end

      def artifact_lines(artifacts)
        lines = []
        lines << "artifacts:"

        REQUIRED_ARTIFACT_KEYS.each do |key, label|
          path = artifacts[key]
          lines << "  #{label}: #{format_value(path)}"
        end

        extra_keys = artifacts.keys.map(&:to_s)
                              .sort
                              .reject { |key| REQUIRED_ARTIFACT_KEYS.any? { |required, _| required.to_s == key } }
        extra_keys.each do |key|
          lines << "  #{key}: #{format_value(artifacts[key.to_sym] || artifacts[key])}"
        end

        lines
      end

      def format_value(value)
        value.nil? ? "n/a" : value
      end

      def validate_artifacts!(artifacts)
        missing = REQUIRED_ARTIFACT_KEYS.filter_map do |key, label|
          path = artifacts[key]
          if path.nil?
            [label, nil]
          elsif !File.exist?(path)
            [label, path]
          end
        end

        return if missing.empty?

        details = {
          "missing_artifacts" => missing.to_h,
          "expected_artifacts" => REQUIRED_ARTIFACT_KEYS.each_with_object({}) do |(key, label), acc|
            acc[label] = artifacts[key]
          end
        }

        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          "Missing required artifacts for CLI summary",
          details: details
        )
      end
    end
  end
end
