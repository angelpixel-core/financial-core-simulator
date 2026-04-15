# frozen_string_literal: true

module FCS
  module Contracts
    class TradeInput
      # TODO: migrate this PORO contract to dry-struct.
      REQUIRED_FIELDS = %i[
        tradeId
        accountId
        marketId
        timestamp
        seq
        side
        quantityBase
        priceQuotePerBase
      ].freeze

      def self.from_hash!(attributes)
        new(attributes).to_h
      end

      def initialize(attributes)
        @attributes = symbolize_keys(attributes)
      end

      def to_h
        missing = REQUIRED_FIELDS.select { |field| @attributes[field].nil? }
        raise ArgumentError, "Missing required fields: #{missing.join(', ')}" unless missing.empty?

        normalized = REQUIRED_FIELDS.each_with_object({}) do |field, out|
          out[field] = @attributes[field]
        end
        normalized[:line] = @attributes[:line] if @attributes.key?(:line)
        normalized
      end

      private

      def symbolize_keys(attributes)
        attributes.each_with_object({}) { |(key, value), out| out[key.to_sym] = value }
      end
    end
  end
end
