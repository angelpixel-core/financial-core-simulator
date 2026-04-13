# typed: true
# frozen_string_literal: true

require "bigdecimal"
require "sorbet-runtime"

module Admin
  module Fx
    module ValueObjects
      class FxRate
        extend T::Sig

        sig { returns(Date) }
        attr_reader :operational_date

        sig { returns(String) }
        attr_reader :base_currency

        sig { returns(String) }
        attr_reader :quote_currency

        sig { returns(BigDecimal) }
        attr_reader :rate

        sig { returns(T.nilable(Integer)) }
        attr_reader :source_id

        sig { returns(T.nilable(String)) }
        attr_reader :source_code

        sig { returns(T.nilable(T::Hash[T.untyped, T.untyped])) }
        attr_reader :raw_payload

        # @param operational_date [Date, String]
        # @param base_currency [String, Symbol]
        # @param quote_currency [String, Symbol]
        # @param rate [BigDecimal, String, Numeric]
        # @param source_id [Integer, nil]
        # @param source_code [String, nil]
        # @param raw_payload [Hash, nil]
        sig do
          params(
            operational_date: T.any(Date, String),
            base_currency: T.any(String, Symbol),
            quote_currency: T.any(String, Symbol),
            rate: T.any(BigDecimal, String, Numeric),
            source_id: T.nilable(Integer),
            source_code: T.nilable(String),
            raw_payload: T.nilable(T::Hash[T.untyped, T.untyped])
          ).void
        end
        def initialize(operational_date:, base_currency:, quote_currency:, rate:, source_id: nil, source_code: nil,
          raw_payload: nil)
          @operational_date = normalize_date(operational_date)
          @base_currency = normalize_currency(base_currency)
          @quote_currency = normalize_currency(quote_currency)
          @rate = normalize_rate(rate)
          @source_id = source_id
          @source_code = source_code
          @raw_payload = raw_payload
        end

        # @param source [String]
        # @return [Hash]
        sig { params(source: String).returns(T::Hash[Symbol, T.untyped]) }
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

        sig { params(value: T.untyped).returns(Date) }
        def normalize_date(value)
          return value if value.is_a?(Date)

          Date.iso8601(value.to_s)
        rescue ArgumentError
          raise ArgumentError, "Invalid operational date"
        end

        sig { params(value: T.untyped).returns(String) }
        def normalize_currency(value)
          normalized = FCS::Currency.normalize(value)
          raise ArgumentError, "Invalid currency code" unless FCS::Currency.valid_code?(normalized)

          normalized
        end

        sig { params(value: T.untyped).returns(BigDecimal) }
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
