# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Admin
  module Fx
    module Ingestion
      module Mappers
        class BcraRateMapper
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

            base_currency, quote_currency, currency_code = pair_config

            if base_currency.blank? || quote_currency.blank?
              return failure("missing_config", message: "Missing FX source currency config")
            end

            errors = []
            rates = []
            adapter = Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter.new(payload)

            begin
              adapter.entries.each do |entry|
                date = entry.date
                entry.details.each do |detail|
                  if currency_code.present? && normalize_currency(detail.currency_code) != normalize_currency(currency_code)
                    next
                  end

                  rate = Admin::Fx::ValueObjects::FxRate.new(
                    operational_date: date,
                    base_currency: base_currency,
                    quote_currency: quote_currency,
                    rate: normalized_rate_value(detail.rate, base_currency: base_currency, quote_currency: quote_currency,
                      currency_code: currency_code),
                    source_id: source.id,
                    source_code: source.code
                  )

                  rates << rate
                end
              end
            rescue Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter::Error => e
              errors << build_error(
                e.entry_index,
                e.detail_index,
                e.field,
                e.message,
                raw_entry: e.raw_entry,
                raw_detail: e.raw_detail
              )
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

          sig { params(key: String).returns(T.untyped) }
          def config_value(key)
            config = source.config
            return nil unless config.is_a?(Hash)

            config[key] || config[key.to_sym]
          end

          sig { params(value: T.untyped).returns(String) }
          def normalize_currency(value)
            FCS::Currency.normalize(value)
          end

          sig { returns(T::Array[String]) }
          def pair_config
            if market.present?
              normalized_market = normalize_market(market)
              if normalized_market.length == 6
                base_currency = normalized_market[0, 3]
                quote_currency = normalized_market[3, 3]
                currency_code = currency_code_for_market(normalized_market) || default_currency_code(base_currency)
                return [base_currency, quote_currency, currency_code]
              end
            end

            base_currency = config_value("base_currency")
            quote_currency = config_value("quote_currency")
            currency_code = default_currency_code(base_currency)
            [base_currency, quote_currency, currency_code]
          end

          sig { params(base_currency: String).returns(String) }
          def default_currency_code(base_currency)
            (config_value("currency_code") || base_currency).to_s.upcase
          end

          sig { params(market_code: String).returns(T.nilable(String)) }
          def currency_code_for_market(market_code)
            raw = config_value("market_currency_codes")
            return nil unless raw.is_a?(Hash)

            symbol_match = raw[market_code] || raw[market_code.to_sym]
            return symbol_match.to_s.upcase if symbol_match.present?

            raw.each do |key, value|
              return value.to_s.upcase if normalize_market(key) == market_code
            end

            nil
          end

          sig { params(raw_rate: BigDecimal, base_currency: String, quote_currency: String, currency_code: String).returns(BigDecimal) }
          def normalized_rate_value(raw_rate, base_currency:, quote_currency:, currency_code:)
            return raw_rate if base_currency == currency_code && quote_currency == "ARS"

            if base_currency == "ARS" && quote_currency == currency_code
              return BigDecimal(1) / raw_rate
            end

            raw_rate
          end

          sig { params(value: T.untyped).returns(String) }
          def normalize_market(value)
            value.to_s.upcase.gsub(/[^A-Z]/, "")
          end

          # @return [Hash]
          sig do
            params(
              entry_index: Integer,
              detail_index: T.nilable(Integer),
              field: String,
              message: String,
              raw_entry: T.nilable(T::Hash[T.untyped, T.untyped]),
              raw_detail: T.nilable(T::Hash[T.untyped, T.untyped])
            ).returns(T::Hash[Symbol, T.untyped])
          end
          def build_error(entry_index, detail_index, field, message, raw_entry: nil, raw_detail: nil)
            {
              entry_index: entry_index,
              detail_index: detail_index,
              field: field,
              message: message,
              raw_entry: raw_entry,
              raw_detail: raw_detail
            }
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
