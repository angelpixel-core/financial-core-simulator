# frozen_string_literal: true

require 'date'

module Admin
  module Fx
    module Providers
      class ManualAdapter < FCS::Ports::FxProvider
        def fetch_rate(base_currency:, quote_currency:, at: nil)
          operational_date = at.is_a?(Date) ? at : Date.parse(at.to_s)
          rate = Admin::Fx::RateResolver.call(
            base_currency: base_currency,
            quote_currency: quote_currency,
            operational_date: operational_date
          )

          {
            rate: rate.rate,
            rate_source: rate.rate_source,
            rate_missing: rate.rate_missing,
            operational_date: operational_date
          }
        end
      end
    end
  end
end
