# frozen_string_literal: true

require "json"
require "securerandom"
require "time"
require "fileutils"

module FCS
  module Reporting
    class JsonReport
      def write!(output_dir:, engine_version:, schema_version:, input_hash:, run_id:, valuation_timestamp: Time.now.utc.iso8601, accounts: [], global: {})
        FileUtils.mkdir_p(output_dir)

        payload = {
          "engineVersion" => engine_version,
          "schemaVersion" => schema_version,
          "inputHash" => input_hash,
          "runId" => run_id,
          "valuationTimestamp" => valuation_timestamp,
          "accounts" => accounts,
          "global" => global
        }

        path = File.join(output_dir, "result.json")
        File.write(path, JSON.pretty_generate(payload) + "\n")
        path
      end
    end
  end
end
