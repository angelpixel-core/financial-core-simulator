# frozen_string_literal: true

require 'date'

module Admin
  module Fx
    module Providers
      class BcraAdapter < FCS::Ports::FxProvider
        RATE_LIMITED_SOURCE = 'bcra_rate_limited'
        INVALID_PAYLOAD_SOURCE = 'bcra_invalid_payload'
        UNAVAILABLE_SOURCE = 'bcra_unavailable'
        BCRA_SOURCE = 'bcra'

        def initialize(client: Admin::Fx::Providers::BcraClient.new,
                       payload_mapper: Admin::Fx::Providers::BcraPayloadMapper.new)
          @client = client
          @payload_mapper = payload_mapper
        end

        def fetch_rate(base_currency:, quote_currency:, at: nil)
          operational_date = nil
          operational_date = at.is_a?(Date) ? at : Date.parse(at.to_s)
          payload = @client.fetch_official_rate(
            base_currency: base_currency,
            quote_currency: quote_currency,
            at: operational_date
          )
          mapped = @payload_mapper.call(payload)

          {
            rate: mapped.fetch(:rate),
            rate_source: BCRA_SOURCE,
            rate_missing: false,
            operational_date: operational_date
          }
        rescue Admin::Fx::Providers::BcraClient::RateLimitedError
          missing_result(source: RATE_LIMITED_SOURCE, operational_date: operational_date)
        rescue Admin::Fx::Providers::BcraPayloadMapper::InvalidPayloadError
          missing_result(source: INVALID_PAYLOAD_SOURCE, operational_date: operational_date)
        rescue NotImplementedError, StandardError
          missing_result(source: UNAVAILABLE_SOURCE, operational_date: operational_date)
        end

        private

        def missing_result(source:, operational_date:)
          {
            rate: nil,
            rate_source: source,
            rate_missing: true,
            operational_date: operational_date
          }
        end
      end
    end
  end
end
