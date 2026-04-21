# typed: ignore
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Admin
  module Fx
    module Ingestion
      module Adapters
        class BinanceAdapter
          ENDPOINT_PATH = "/api/v3/klines"
          DEFAULT_LIMIT = 1000
          DEFAULT_INTERVAL = "1d"

          def initialize(source:)
            @source = source
            @config = source.config || {}
          end

          def fetch(date_from:, date_to:, limit: nil, offset: 0, market: nil)
            base_url = config_value("base_url")
            symbol = normalize_market(market.presence || default_market)
            interval = config_value("interval") || DEFAULT_INTERVAL
            normalized_limit = normalize_limit(limit)

            return missing_config_result("base_url") if base_url.blank?
            return missing_config_result("market") if symbol.blank?
            return failure("invalid_market", market: symbol) unless available_markets.include?(symbol)

            uri = build_uri(
              base_url: base_url,
              symbol: symbol,
              interval: interval,
              date_from: date_from,
              date_to: date_to,
              limit: normalized_limit
            )

            response = Net::HTTP.get_response(uri)
            status = response.code.to_i

            return failure("http_error", status: status, url: uri.to_s) unless status.between?(200, 299)

            payload = JSON.parse(response.body)
            normalized_payload = normalize_payload(payload,
              status: status,
              limit: normalized_limit,
              offset: offset,
              market: symbol,
              interval: interval)

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

          def available_markets
            Array(config_value("markets")).map { |item| normalize_market(item) }.compact
          end

          def default_market
            available_markets.first
          end

          def normalize_market(value)
            value.to_s.upcase.gsub(/[^A-Z0-9]/, "").presence
          end

          def normalize_limit(limit)
            configured = config_value("default_limit").to_i
            base_limit = limit.to_i.positive? ? limit.to_i : configured
            return DEFAULT_LIMIT if base_limit <= 0

            [base_limit, DEFAULT_LIMIT].min
          end

          def build_uri(base_url:, symbol:, interval:, date_from:, date_to:, limit:)
            normalized_base = base_url.end_with?("/") ? base_url : "#{base_url}/"
            uri = URI.join(normalized_base, ENDPOINT_PATH)
            uri.query = URI.encode_www_form(
              symbol: symbol,
              interval: interval,
              startTime: date_from.to_time(:utc).beginning_of_day.to_i * 1000,
              endTime: date_to.to_time(:utc).end_of_day.to_i * 1000,
              limit: limit
            )
            uri
          end

          def normalize_payload(payload, status:, limit:, offset:, market:, interval:)
            return payload if payload.is_a?(Hash) && payload.key?("status") && payload.key?("metadata") && payload.key?("results")

            rows = Array(payload).filter_map do |kline|
              next unless kline.is_a?(Array) && kline.length >= 7

              {
                "open_time" => kline[0],
                "close" => kline[4],
                "close_time" => kline[6],
                "raw" => kline
              }
            end

            {
              "status" => status,
              "metadata" => {
                "resultset" => {
                  "count" => rows.length,
                  "offset" => offset,
                  "limit" => limit
                },
                "market" => market,
                "interval" => interval
              },
              "results" => rows
            }
          end

          def missing_config_result(key)
            failure("missing_config", missing_key: key)
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
