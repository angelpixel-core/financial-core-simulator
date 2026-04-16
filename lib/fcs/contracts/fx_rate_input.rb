# frozen_string_literal: true

module FCS
  module Contracts
    class FxRateInput
      # TODO: migrate this PORO contract to dry-struct.
      REQUIRED_FIELDS = %i[baseCurrency quoteCurrency rate].freeze

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
          baseCurrency: @attributes.fetch(:baseCurrency).to_s,
          quoteCurrency: @attributes.fetch(:quoteCurrency).to_s,
          rate: @attributes.fetch(:rate).to_s,
          asOf: @attributes[:asOf]
        }.compact
      end

      private

      def blank?(value)
        value.nil? || (value.respond_to?(:strip) && value.strip.empty?)
      end
    end
  end
end
