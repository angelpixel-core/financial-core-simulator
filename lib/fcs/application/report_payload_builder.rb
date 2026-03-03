module FCS
  module Application
    class ReportPayloadBuilder
      def self.build(engine_version:, schema_version:, input_hash:, run_id:, valuation_timestamp:, accounts:, global:,
                     replay: nil)
        payload = {
          'engineVersion' => engine_version,
          'schemaVersion' => schema_version,
          'inputHash' => input_hash,
          'runId' => run_id,
          'valuationTimestamp' => valuation_timestamp,
          'accounts' => accounts,
          'global' => global
        }

        payload['replay'] = replay unless replay.nil?
        payload
      end
    end
  end
end
