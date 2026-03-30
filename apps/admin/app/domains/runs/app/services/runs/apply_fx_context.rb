# frozen_string_literal: true

require 'bigdecimal'
require 'json'

module Runs
  class ApplyFxContext
    DEFAULT_OPERATOR_FEE_FACTOR = '1.0'

    def self.call(run:, operator_fee_factor: nil)
      new.call(run: run, operator_fee_factor: operator_fee_factor)
    end

    def call(run:, operator_fee_factor: nil)
      raise 'Run#input_json is required' if run.input_json.blank?

      input = deep_copy(run.input_json)

      existing_context = input['fxContext'] || run.fx_context
      if existing_context.is_a?(Hash)
        input['fxContext'] ||= existing_context
        run.update!(input_json: input, fx_context: existing_context)
        return existing_context
      end

      reporting_currency = ReportingSetting.current.reporting_currency
      valuation_timestamp = input.dig('priceSnapshot', 'valuationTimestamp')
      operational_date = Admin::Fx::OperationalDate.call(timestamp: valuation_timestamp)

      rate_result = Admin::Fx::RateResolver.call(
        base_currency: Admin::Fx::RateResolver::BASE_CURRENCY,
        quote_currency: reporting_currency,
        operational_date: operational_date
      )

      fee_factor = normalize_decimal(operator_fee_factor || DEFAULT_OPERATOR_FEE_FACTOR)

      fx_context = {
        'reportingCurrency' => reporting_currency,
        'operatorFeeFactor' => fee_factor,
        'rate' => rate_result.rate,
        'rateDate' => operational_date.iso8601,
        'rateSource' => rate_result.rate_source,
        'rateMissing' => rate_result.rate_missing
      }

      input['fxContext'] = fx_context
      run.update!(input_json: input, fx_context: fx_context)
      fx_context
    end

    private

    def deep_copy(data)
      JSON.parse(JSON.generate(data))
    end

    def normalize_decimal(value)
      decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
      raise ArgumentError, 'operator fee factor must be positive' if decimal <= 0

      decimal.to_s('F')
    end
  end
end
