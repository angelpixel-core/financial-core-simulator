# frozen_string_literal: true

module FCS
  module Application
    class Runner
      def initialize(
        parser: FCS::Ingestion::Parser.new,
        validator: FCS::Ingestion::Validator.new,
        sorter: FCS::Engine::TradeSorter.new,
        simulate: FCS::Application::Simulate.new,
        reporter: FCS::Reporting::JsonReport.new,
        positions_csv: FCS::Reporting::CsvPositions.new,
        pnl_csv: FCS::Reporting::CsvPnL.new,
        cli: FCS::Reporting::CliSummary.new
      )
        @parser = parser
        @validator = validator
        @sorter = sorter
        @simulate = simulate
        @reporter = reporter
        @positions_csv = positions_csv
        @pnl_csv = pnl_csv
        @cli = cli
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

        result = @simulate.call(input)

        json_path = @reporter.write!(
          output_dir: output_dir,
          engine_version: FCS::VERSION,
          schema_version: schema_version,
          input_hash: input_hash,
          valuation_timestamp: valuation_ts,
          accounts: result.fetch("accounts"),
          global: result.fetch("global")
        )

        @positions_csv.write!(output_dir: output_dir, accounts: result.fetch("accounts"))
        @pnl_csv.write!(output_dir: output_dir, accounts: result.fetch("accounts"))
        @cli.print(
          "engineVersion" => FCS::VERSION,
          "schemaVersion" => schema_version,
          "inputHash" => input_hash,
          "runId" => JSON.parse(File.read(json_path)).fetch("runId"),
          "valuationTimestamp" => valuation_ts,
          "accounts" => result.fetch("accounts"),
          "global" => result.fetch("global")
        )

        json_path
      end
    end
  end
end
