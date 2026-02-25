# frozen_string_literal: true

require "json"
require "securerandom"
require "time"
require "fileutils"

module FCS
  module Reporting
    class JsonReport
      def write!(output_dir:, engine_version:, schema_version:, input_hash:, valuation_timestamp: Time.now.utc.iso8601)
        FileUtils.mkdir_p(output_dir)

        payload = {
          "engineVersion" => engine_version,
          "schemaVersion" => schema_version,
          "inputHash" => input_hash,
          "runId" => SecureRandom.uuid,
          "valuationTimestamp" => valuation_timestamp,
          # Stub: el engine todavía no corre. Dejamos lugar ya con estructura.
          "accounts" => [],
          "global" => {
            "pnlQuote" => "0",
            "pnlUsd" => nil
          }
        }

        path = File.join(output_dir, "result.json")
        File.write(path, JSON.pretty_generate(payload) + "\n")
        path
      end
    end
  end
end
