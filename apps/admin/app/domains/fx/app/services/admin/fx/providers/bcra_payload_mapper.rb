# frozen_string_literal: true

require "bigdecimal"

module Admin
  module Fx
    module Providers
      class BcraPayloadMapper
        class InvalidPayloadError < StandardError; end

        def call(payload)
          result = Array(payload.fetch("results")).first
          raise InvalidPayloadError, "missing results payload" unless result.is_a?(Hash)

          raw_rate = result["close"]
          rate = BigDecimal(raw_rate.to_s)
          raise InvalidPayloadError, "non-positive rate" unless rate.positive?

          {
            rate: rate.to_s("F"),
            rate_date: result["date"]
          }
        rescue KeyError, ArgumentError
          raise InvalidPayloadError, "unexpected BCRA payload format"
        end
      end
    end
  end
end
