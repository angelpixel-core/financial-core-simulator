# frozen_string_literal: true

module FCS
  module Application
    # Builds report payloads from simulation results.
    #
    # @example
    #   payload = FCS::Application::ReportPayloadBuilder.build(
    #     engine_version: FCS::VERSION,
    #     schema_version: "1",
    #     input_hash: "...",
    #     run_id: "...",
    #     valuation_timestamp: "2024-01-01T00:00:00Z",
    #     accounts: accounts,
    #     global: global
    #   )
    class ReportPayloadBuilder
      # @param engine_version [String]
      # @param schema_version [String]
      # @param input_hash [String]
      # @param run_id [String]
      # @param valuation_timestamp [String]
      # @param accounts [Array<Hash>]
      # @param global [Hash]
      # @param replay [Hash, nil]
      # @return [Hash]
      def self.build(engine_version:, schema_version:, input_hash:, run_id:, valuation_timestamp:, accounts:, global:,
                     replay: nil)
        payload = {
          "engineVersion" => engine_version,
          "schemaVersion" => schema_version,
          "inputHash" => input_hash,
          "runId" => run_id,
          "valuationTimestamp" => valuation_timestamp,
          "accounts" => accounts,
          "global" => global
        }

        payload["replay"] = replay unless replay.nil?
        payload
      end
    end
  end
end
