# frozen_string_literal: true

module Admin
  module Fx
    class MissingRatePopupComponent < ViewComponent::Base
      def initialize(
        operational_date:,
        reporting_currency:,
        base_currency:,
        quote_currency:,
        carry_forward_available:,
        rate_missing: true
      )
        @operational_date = operational_date
        @reporting_currency = reporting_currency
        @base_currency = base_currency
        @quote_currency = quote_currency
        @carry_forward_available = carry_forward_available
        @rate_missing = rate_missing
      end

      def render?
        @rate_missing
      end

      def operational_date_label
        I18n.l(@operational_date, format: :long)
      end

      def operational_date_value
        @operational_date.iso8601
      end

      attr_reader :base_currency, :quote_currency, :reporting_currency

      def carry_forward_available?
        @carry_forward_available
      end
    end
  end
end
