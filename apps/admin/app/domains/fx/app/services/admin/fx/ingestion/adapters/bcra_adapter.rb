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
          DEFAULT_CHUNK_DAYS = 7
          ENDPOINT_PATH = "Cotizaciones"

          def initialize(source:)
            @source = source
            @config = source.config || {}
          end

          def fetch(date_from:, date_to:, limit: DEFAULT_LIMIT, offset: 0, market: nil)
            base_url = config_value("base_url")
            currency_code = currency_code_for(market)

            return missing_config_result("base_url") if base_url.blank?
            return missing_config_result("currency_code") if currency_code.blank?

            urls = []
            combined_results = []
            status = nil

            chunk_ranges(date_from: date_from, date_to: date_to).each do |chunk_from, chunk_to|
              uri = build_uri(
                base_url: base_url,
                currency_code: currency_code,
                date_from: chunk_from,
                date_to: chunk_to,
                limit: limit,
                offset: offset
              )

              response = Net::HTTP.get_response(uri)
              status = response.code.to_i
              urls << uri.to_s

              unless status.between?(200, 299)
                return failure("http_error", status: status, url: uri.to_s, chunk_from: chunk_from,
                  chunk_to: chunk_to)
              end

              payload = JSON.parse(response.body)
              normalized_payload = normalize_payload(payload, status: status, limit: limit, offset: offset)
              combined_results.concat(Array(normalized_payload["results"]))
            end

            normalized_payload = {
              "status" => status,
              "metadata" => {
                "resultset" => {
                  "count" => combined_results.length,
                  "offset" => offset,
                  "limit" => limit
                }
              },
              "results" => combined_results
            }

            Admin::Fx::Ingestion::Result.success(
              data: {payload: normalized_payload},
              metadata: {status: status, url: urls.first, urls: urls}
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

          def currency_code_for(market)
            normalized_market = normalize_market(market)
            if normalized_market.present?
              configured = market_currency_codes[normalized_market]
              return configured if configured.present?

              base_currency, quote_currency = normalized_market[0, 3], normalized_market[3, 3]
              return base_currency if quote_currency == "ARS"
              return quote_currency if base_currency == "ARS"
            end

            config_value("currency_code") || config_value("base_currency")
          end

          def market_currency_codes
            raw = config_value("market_currency_codes")
            return {} unless raw.is_a?(Hash)

            raw.each_with_object({}) do |(key, value), memo|
              memo[normalize_market(key)] = value.to_s.upcase
            end
          end

          def normalize_market(value)
            value.to_s.upcase.gsub(/[^A-Z]/, "").presence
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

          def chunk_ranges(date_from:, date_to:)
            from = Date.iso8601(date_from.to_s)
            to = Date.iso8601(date_to.to_s)
            chunk_days = chunk_days_per_request

            ranges = []
            current = from
            while current <= to
              chunk_to = [current + (chunk_days - 1), to].min
              ranges << [current, chunk_to]
              current = chunk_to + 1
            end

            ranges
          rescue ArgumentError
            [[date_from, date_to]]
          end

          def chunk_days_per_request
            value = ENV.fetch("BCRA_SYNC_CHUNK_DAYS", DEFAULT_CHUNK_DAYS).to_i
            value.positive? ? value : DEFAULT_CHUNK_DAYS
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
