# frozen_string_literal: true

module Admin
  module Fx
    class GapResolver
      def self.call(rate: nil, operational_date: nil, base_currency: nil, quote_currency: nil, action: :resolve)
        new.call(
          rate: rate,
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          action: action
        )
      end

      def call(rate: nil, operational_date: nil, base_currency: nil, quote_currency: nil, action: :resolve)
        if rate
          return if rate.rate.nil?

          operational_date ||= rate.operational_date
          base_currency ||= rate.base_currency
          quote_currency ||= rate.quote_currency
        end

        gap = FxRateGap.open_for(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency
        )
        return if gap.nil?

        case action.to_sym
        when :ignore
          gap.ignore!
        else
          gap.resolve!(rate: rate)
        end
      end
    end
  end
end
