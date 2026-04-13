# frozen_string_literal: true

require "bigdecimal"

module Admin
  module Fx
    module Ingestion
      module Mappers
        class BcraRateMapper
          def self.call(payload:, source:)
            new(payload: payload, source: source).call
          end

          def initialize(payload:, source:)
            @payload = payload
            @source = source
          end

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

            Array(payload["results"]).each_with_index do |entry, entry_index|
              date = parse_date(entry["fecha"])
              if date.nil?
                errors << build_error(entry_index, nil, "fecha", "Invalid date")
                next
              end

              details = Array(entry["detalle"])
              if details.empty?
                errors << build_error(entry_index, nil, "detalle", "Missing detail entries")
                next
              end

              details.each_with_index do |detail, detail_index|
                if currency_code.present? && normalize_currency(detail["codigoMoneda"]) != normalize_currency(currency_code)
                  next
                end

                rate_value = parse_rate(detail["tipoCotizacion"])
                if rate_value.nil?
                  errors << build_error(entry_index, detail_index, "tipoCotizacion", "Invalid rate")
                  next
                end

                rate = Admin::Fx::ValueObjects::FxRate.new(
                  operational_date: date,
                  base_currency: base_currency,
                  quote_currency: quote_currency,
                  rate: rate_value,
                  source_id: source.id,
                  source_code: source.code,
                  raw_payload: {"entry" => entry, "detail" => detail}
                )

                rates << rate
              rescue ArgumentError => e
                errors << build_error(entry_index, detail_index, "rate", e.message)
              end
            end

            return failure("mapping_failed", errors: errors) if errors.any?

            Admin::Fx::Ingestion::Result.success(data: {rates: rates})
          end

          private

          attr_reader :payload, :source

          def config_value(key)
            config = source&.config
            return nil unless config.is_a?(Hash)

            config[key] || config[key.to_sym]
          end

          def normalize_currency(value)
            FCS::Currency.normalize(value)
          end

          def parse_date(value)
            return nil if value.blank?

            Date.iso8601(value.to_s)
          rescue ArgumentError
            nil
          end

          def parse_rate(value)
            return nil if value.blank?

            decimal = BigDecimal(value.to_s)
            return nil unless decimal.positive?

            decimal
          rescue ArgumentError
            nil
          end

          def build_error(entry_index, detail_index, field, message)
            {
              entry_index: entry_index,
              detail_index: detail_index,
              field: field,
              message: message
            }
          end

          def failure(error_code, context = {})
            Admin::Fx::Ingestion::Result.failure(
              error_code: error_code,
              context: context,
              metadata: {source_id: source&.id}
            )
          end
        end
      end
    end
  end
end
