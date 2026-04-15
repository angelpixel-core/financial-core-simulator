# frozen_string_literal: true

module FCS
  module Contracts
    class RunExecutionResult
      # TODO: migrate this PORO contract to dry-struct.
      REQUIRED_FIELDS = %i[json_path input_hash run_id schema_version artifacts].freeze

      def self.from_hash!(attributes)
        new(attributes).to_h
      end

      def initialize(attributes)
        @attributes = attributes.each_with_object({}) { |(key, value), out| out[key.to_sym] = value }
      end

      def to_h
        missing = REQUIRED_FIELDS.select { |field| blank?(@attributes[field]) }
        raise ArgumentError, "Missing required fields: #{missing.join(", ")}" unless missing.empty?

        {
          json_path: @attributes.fetch(:json_path).to_s,
          input_hash: @attributes.fetch(:input_hash).to_s,
          run_id: @attributes.fetch(:run_id).to_s,
          schema_version: @attributes.fetch(:schema_version).to_s,
          valuation_timestamp: @attributes[:valuation_timestamp],
          artifacts: @attributes.fetch(:artifacts)
        }
      end

      private

      def blank?(value)
        value.nil? || (value.respond_to?(:strip) && value.strip.empty?)
      end
    end
  end
end
