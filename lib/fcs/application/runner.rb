# frozen_string_literal: true

module FCS
  module Application
    class Runner
      def initialize(
        parser: FCS::Ingestion::Parser.new,
        validator: FCS::Ingestion::Validator.new,
        sorter: FCS::Engine::TradeSorter.new,
        reporter: FCS::Reporting::JsonReport.new
      )
        @parser = parser
        @validator = validator
        @sorter = sorter
        @reporter = reporter
      end

      def run!(input_path:, output_dir:, fee_enabled:)
        input = @parser.parse_file(input_path)

        # CLI flag tiene precedencia (y además deja el input normalizado)
        input["feeModel"] ||= {}
        input["feeModel"]["enabled"] = !!fee_enabled

        @validator.validate!(input)

        # Determinismo: ordenar trades antes de hashear + antes del engine
        input["trades"] = @sorter.sort(input.fetch("trades"))

        canonical = FCS::Hashing::CanonicalJSON.dump(input)
        input_hash = FCS::Hashing::SHA256.hex(canonical)

        schema_version = input.fetch("schemaVersion")
        valuation_ts =
          input.dig("priceSnapshot", "valuationTimestamp") # opcional; si falta, reporter usa Time.now.utc

        @reporter.write!(
          output_dir: output_dir,
          engine_version: FCS::VERSION,
          schema_version: schema_version,
          input_hash: input_hash,
          valuation_timestamp: valuation_ts
        )
      end
    end
  end
end
