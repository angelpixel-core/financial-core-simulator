# frozen_string_literal: true

module Admin
  module Fx
    module Providers
      class BcraClient
        class RateLimitedError < StandardError; end

        def fetch_official_rate(base_currency:, quote_currency:, at:)
          _ = [base_currency, quote_currency, at]
          raise NotImplementedError, "BCRA client integration not configured"
        end
      end
    end
  end
end
