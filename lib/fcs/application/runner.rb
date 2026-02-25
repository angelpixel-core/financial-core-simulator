# frozen_string_literal: true

module FCS
  module Application
    class Runner
      def initialize(parser: FCS::Ingestion::Parser.new,
                     validator: FCS::Ingestion::Validator.new,
                     reporter: FCS::Reporting::JsonReport.new)
        @parser = parser
        @validator = validator
        @reporter = reporter
      end

      def run!(input_path:, output_dir:, fee_enabled:)
        input = @parser.parse_file(input_path)

        # Hook: si en el futuro el input trae feeModel, lo respetamos; por ahora solo flag CLI.
        input["feeModel"] ||= {}
        input["feeModel"]["enabled"] = fee_enabled

        @validator.validate!(input)

        canonical = FCS::Hashing::CanonicalJSON.dump(input)
        input_hash = FCS::Hashing::SHA256.hex(canonical)

        schema_version = input.fetch("schemaVersion", nil)

        @reporter.write!(
          output_dir: output_dir,
          engine_version: FCS::VERSION,
          schema_version: schema_version,
          input_hash: input_hash
        )
      end
    end
  end
end
