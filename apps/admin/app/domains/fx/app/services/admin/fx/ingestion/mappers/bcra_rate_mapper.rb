# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Admin
  module Fx
    module Ingestion
      module Mappers
        class BcraRateMapper
          extend T::Sig

          sig { params(payload: T::Hash[T.untyped, T.untyped], source: FxRateSource).returns(Result) }
          def self.call(payload:, source:)
            new(payload: payload, source: source).call
          end

          sig { params(payload: T::Hash[T.untyped, T.untyped], source: FxRateSource).void }
          def initialize(payload:, source:)
            @payload = payload
            @source = source
          end

          sig { returns(Result) }
          def call
            return failure("missing_payload", message: "Payload is required") unless payload.is_a?(Hash)

            base_currency = config_value("base_currency")
            quote_currency = config_value("quote_currency")
            currency_code = config_value("currency_code") || base_currency

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
                    rate: detail.rate,
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
