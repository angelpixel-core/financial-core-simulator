# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Admin
  module Fx
    module Ingestion
      module Mappers
        class BinanceRateMapper
          extend T::Sig

          sig { params(payload: T::Hash[T.untyped, T.untyped], source: FxRateSource, market: T.nilable(String)).returns(Result) }
          def self.call(payload:, source:, market: nil)
            new(payload: payload, source: source, market: market).call
          end

          sig { params(payload: T::Hash[T.untyped, T.untyped], source: FxRateSource, market: T.nilable(String)).void }
          def initialize(payload:, source:, market: nil)
            @payload = payload
            @source = source
            @market = market
          end

          sig { returns(Result) }
          def call
            return failure("missing_payload", message: "Payload is required") unless payload.is_a?(Hash)

            base_currency, quote_currency = pair_from_market
            if base_currency.nil? || base_currency.empty? || quote_currency.nil? || quote_currency.empty?
              return failure("invalid_market", market: market)
            end
            base_currency = T.must(base_currency)
            quote_currency = T.must(quote_currency)

            rates = []
            errors = []

            Array(payload["results"]).each_with_index do |row, index|
              operational_date = Time.at(Integer(row.fetch("open_time")) / 1000).utc.to_date
              raw_quote_currency = normalize_currency(quote_currency)
              normalized_quote = (raw_quote_currency == "USDT") ? "USD" : raw_quote_currency

              rate = Admin::Fx::ValueObjects::FxRate.new(
                operational_date: operational_date,
                base_currency: base_currency,
                quote_currency: normalized_quote,
                rate: row.fetch("close"),
                source_id: source.id,
                source_code: source.code,
                raw_payload: {"market" => market, "row" => row}
              )

              rates << rate
            rescue => e
              errors << {
                row_index: index,
                message: e.message,
                raw_row: row
              }
            end

            return failure("mapping_failed", errors: errors) if errors.any?

            Admin::Fx::Ingestion::Result.success(data: {rates: rates})
          end

          private

          sig { returns(T::Hash[T.untyped, T.untyped]) }
          attr_reader :payload

          sig { returns(FxRateSource) }
          attr_reader :source

          sig { returns(T.nilable(String)) }
          attr_reader :market

          sig { returns(T::Array[T.nilable(String)]) }
          def pair_from_market
            normalized_market = market.to_s.upcase.gsub(/[^A-Z0-9]/, "")
            configured_markets = Array(source.config["markets"]).map { |value| value.to_s.upcase }
            return [nil, nil] unless configured_markets.include?(normalized_market)

            if normalized_market.end_with?("USDT")
              return [normalize_currency(normalized_market.delete_suffix("USDT")), "USDT"]
            end

            [nil, nil]
          end

          sig { params(value: T.untyped).returns(String) }
          def normalize_currency(value)
            FCS::Currency.normalize(value)
          end

          sig { params(error_code: String, context: T::Hash[T.untyped, T.untyped]).returns(Result) }
          def failure(error_code, context = {})
            Admin::Fx::Ingestion::Result.failure(
              error_code: error_code,
              context: context,
              metadata: {source_id: source.id}
            )
          end
        end
      end
    end
  end
end
