# frozen_string_literal: true

require "bigdecimal"

module Admin
  module Fx
    module ValueObjects
      class FxRate
        attr_reader :operational_date, :base_currency, :quote_currency, :rate, :source_id, :source_code, :raw_payload

        def initialize(operational_date:, base_currency:, quote_currency:, rate:, source_id: nil, source_code: nil,
          raw_payload: {})
          @operational_date = normalize_date(operational_date)
          @base_currency = normalize_currency(base_currency)
          @quote_currency = normalize_currency(quote_currency)
          @rate = normalize_rate(rate)
          @source_id = source_id
          @source_code = source_code
          @raw_payload = raw_payload || {}
        end

        def to_upsert_attributes(source: "ingestion")
          {
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency,
            rate: rate,
            source: source,
            source_id: source_id
          }
        end

        private

        def normalize_date(value)
          return value if value.is_a?(Date)

          Date.iso8601(value.to_s)
        rescue ArgumentError
          raise ArgumentError, "Invalid operational date"
        end

        def normalize_currency(value)
          normalized = FCS::Currency.normalize(value)
          raise ArgumentError, "Invalid currency code" unless FCS::Currency.valid_code?(normalized)

          normalized
        end

        def normalize_rate(value)
          decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
          raise ArgumentError, "Rate must be greater than 0" unless decimal.positive?

          decimal
        rescue ArgumentError
          raise ArgumentError, "Invalid rate"
        end
      end
    end
  end
end
