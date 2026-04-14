# typed: ignore
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Admin
  module Fx
    module Ingestion
      module Adapters
        class BcraAdapter
          DEFAULT_LIMIT = 1000
          ENDPOINT_PATH = "Cotizaciones"

          def initialize(source:)
            @source = source
            @config = source.config || {}
          end

          def fetch(date_from:, date_to:, limit: DEFAULT_LIMIT, offset: 0)
            base_url = config_value("base_url")
            currency_code = config_value("currency_code") || config_value("base_currency")

            return missing_config_result("base_url") if base_url.blank?
            return missing_config_result("currency_code") if currency_code.blank?

            uri = build_uri(base_url: base_url, currency_code: currency_code, date_from: date_from,
              date_to: date_to, limit: limit, offset: offset)

            response = Net::HTTP.get_response(uri)
            status = response.code.to_i

            return failure("http_error", status: status, url: uri.to_s) unless status.between?(200, 299)

            payload = JSON.parse(response.body)
            normalized_payload = normalize_payload(payload, status: status, limit: limit, offset: offset)

            Admin::Fx::Ingestion::Result.success(
              data: {payload: normalized_payload},
              metadata: {status: status, url: uri.to_s}
            )
          rescue JSON::ParserError => e
            failure("invalid_json", error: e.message)
          rescue => e
            failure("http_error", error: e.message)
          end

          def default_range(to_date: Date.current, days: 30)
            end_date = to_date
            start_date = end_date - (days - 1)
            [start_date, end_date]
          end

          private

          attr_reader :source, :config

          def config_value(key)
            config.is_a?(Hash) ? config[key] || config[key.to_sym] : nil
          end

          def build_uri(base_url:, currency_code:, date_from:, date_to:, limit:, offset:)
            normalized_base = base_url.end_with?("/") ? base_url : "#{base_url}/"
            uri = URI.join(normalized_base, "#{ENDPOINT_PATH}/#{currency_code}")
            uri.query = URI.encode_www_form(
              fechadesde: date_from,
              fechahasta: date_to,
              limit: limit,
              offset: offset
            )
            uri
          end

          def missing_config_result(key)
            failure("missing_config", missing_key: key)
          end

          def normalize_payload(payload, status:, limit:, offset:)
            if payload.is_a?(Hash) && payload.key?("status") && payload.key?("metadata") && payload.key?("results")
              return payload
            end

            if payload.is_a?(Array)
              return {
                "status" => status,
                "metadata" => {
                  "resultset" => {
                    "count" => payload.length,
                    "offset" => offset,
                    "limit" => limit
                  }
                },
                "results" => payload
              }
            end

            normalized = payload.is_a?(Hash) ? payload.dup : {"results" => payload}
            normalized["status"] ||= status
            normalized["results"] ||= []
            normalized["metadata"] ||= {}
            normalized["metadata"]["resultset"] ||= {
              "count" => normalized["results"].length,
              "offset" => offset,
              "limit" => limit
            }
            normalized
          end

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
