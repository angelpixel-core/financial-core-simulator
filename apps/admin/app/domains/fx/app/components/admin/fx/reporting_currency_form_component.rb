# frozen_string_literal: true

module Admin
  module Fx
    class ReportingCurrencyFormComponent < ViewComponent::Base
      def initialize(
        reporting_setting:,
        supported_currencies:,
        fx_rate_state:,
        operational_date:,
        base_currency:,
        quote_currency:
      )
        @reporting_setting = reporting_setting
        @supported_currencies = supported_currencies
        @fx_rate_state = fx_rate_state
        @operational_date = operational_date
        @base_currency = base_currency
        @quote_currency = quote_currency
      end

      attr_reader :reporting_setting,
                  :supported_currencies,
                  :fx_rate_state,
                  :operational_date,
                  :base_currency,
                  :quote_currency
    end
  end
end
