# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "date"

module Admin
  module Fx
    module Providers
      class BcraClient
        class RateLimitedError < StandardError; end

        BASE_URL = "https://api.bcra.gob.ar/estadisticascambiarias/v1.0"
        ENDPOINT_PATH = "Cotizaciones"
        DEFAULT_LIMIT = 1

        def fetch_official_rate(base_currency:, quote_currency:, at:)
          currency_code = resolve_currency_code(base_currency: base_currency, quote_currency: quote_currency)
          raise NotImplementedError, "unsupported pair for BCRA" if currency_code.blank?

          operational_date = at.is_a?(Date) ? at : Date.parse(at.to_s)
          uri = build_uri(currency_code: currency_code, at: operational_date)
          response = Net::HTTP.get_response(uri)
          status = response.code.to_i

          raise RateLimitedError if status == 429
          raise StandardError, "BCRA request failed with status #{status}" unless status.between?(200, 299)

          payload = JSON.parse(response.body)
          normalize_payload(payload: payload, currency_code: currency_code)
        rescue JSON::ParserError => e
          raise StandardError, "BCRA invalid JSON: #{e.message}"
        end

        private

        def resolve_currency_code(base_currency:, quote_currency:)
          base = base_currency.to_s.upcase
          quote = quote_currency.to_s.upcase

          return base if quote == "ARS"
          return quote if base == "ARS"

          nil
        end

        def build_uri(currency_code:, at:)
          uri = URI.join("#{BASE_URL}/", "#{ENDPOINT_PATH}/#{currency_code}")
          date_value = at.iso8601
          uri.query = URI.encode_www_form(
            fechadesde: date_value,
            fechahasta: date_value,
            limit: DEFAULT_LIMIT,
            offset: 0
          )
          uri
        end

        def normalize_payload(payload:, currency_code:)
          results = Array(payload["results"])
          first = results.first
          raise StandardError, "BCRA payload missing results" unless first.is_a?(Hash)

          if first["close"].present?
            return {"results" => [{"date" => first["date"], "close" => first["close"]}]}
          end

          if first["fecha"].present? && first["detalle"].is_a?(Array)
            detail = first["detalle"].find do |entry|
              entry.is_a?(Hash) && entry["codigoMoneda"].to_s.upcase == currency_code
            end
            raise StandardError, "BCRA payload missing currency detail" unless detail

            return {
              "results" => [
                {
                  "date" => first["fecha"],
                  "close" => detail["tipoCotizacion"]
                }
              ]
            }
          end

          raise StandardError, "BCRA payload format unsupported"
        end
      end
    end
  end
end
