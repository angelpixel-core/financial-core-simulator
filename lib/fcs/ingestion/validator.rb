# frozen_string_literal: true

module FCS
  module Ingestion
    class Validator
      SUPPORTED_SCHEMA_VERSIONS = ["1.0"].freeze

      def validate!(input_hash)
        schema_version = input_hash["schemaVersion"]
        unless SUPPORTED_SCHEMA_VERSIONS.include?(schema_version)
          raise FCS::Error.new(
            FCS::Errors::ERR_UNSUPPORTED_SCHEMA,
            "Unsupported schemaVersion",
            details: { schemaVersion: schema_version, supported: SUPPORTED_SCHEMA_VERSIONS }
          )
        end

        # TODO: NFR3 validations (seq unique, snapshot complete, refs, qty/price > 0, etc.)
        true
      end
    end
  end
end
