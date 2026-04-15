# frozen_string_literal: true

require "bigdecimal"

module FCS
  module Application
    class NormalizeFxContext
      DEFAULT_OPERATOR_FEE_FACTOR = "1.0"

      def call(reporting_currency:, rate_data:, operational_date:, operator_fee_factor: DEFAULT_OPERATOR_FEE_FACTOR)
        {
          "reportingCurrency" => reporting_currency,
          "operatorFeeFactor" => normalize_decimal(operator_fee_factor),
          "rate" => rate_data[:rate],
          "rateDate" => operational_date.iso8601,
          "rateSource" => rate_data[:rate_source],
          "rateMissing" => rate_data[:rate_missing]
        }
      end

      private

      def normalize_decimal(value)
        decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
        raise ArgumentError, "operator fee factor must be positive" if decimal <= 0

        decimal.to_s("F")
      end
    end
  end
end
