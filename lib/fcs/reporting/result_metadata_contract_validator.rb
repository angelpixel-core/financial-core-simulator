# frozen_string_literal: true

module FCS
  module Reporting
    class ResultMetadataContractValidator
      REQUIRED_FIELDS = %w[engineVersion schemaVersion inputHash runId valuationTimestamp].freeze
      INPUT_HASH_REGEX = /\A[0-9a-f]{64}\z/
      RUN_ID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
      ISO_UTC_REGEX = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/

      def validate!(payload:)
        REQUIRED_FIELDS.each do |field|
          value = payload[field]
          next unless value.nil? || (value.is_a?(String) && value.strip.empty?)

          raise_contract_error!(
            message: 'result metadata missing required field',
            field: field,
            invalid_value: value
          )
        end

        validate_format!(payload.fetch('inputHash'), field: 'inputHash', regex: INPUT_HASH_REGEX)
        validate_format!(payload.fetch('runId'), field: 'runId', regex: RUN_ID_REGEX)
        validate_format!(payload.fetch('valuationTimestamp'), field: 'valuationTimestamp', regex: ISO_UTC_REGEX)
      end

      private

      def validate_format!(value, field:, regex:)
        return if value.is_a?(String) && value.match?(regex)

        raise_contract_error!(
          message: 'result metadata has invalid format',
          field: field,
          invalid_value: value
        )
      end

      def raise_contract_error!(message:, field:, invalid_value: nil)
        details = {
          'field' => field,
          'impact' => 'Canonical result metadata cannot be trusted for this run.',
          'next_action' => 'Ensure metadata fields are present and formatted as required (ISO-8601 UTC timestamps, deterministic identifiers).'
        }
        details['invalid_value'] = invalid_value unless invalid_value.nil?

        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          message,
          details: details
        )
      end
    end
  end
end
