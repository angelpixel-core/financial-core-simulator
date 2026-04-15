# frozen_string_literal: true

require "json"

module Runs
  class ApplyFxContext
    def self.call(run:, operator_fee_factor: nil)
      new.call(run: run, operator_fee_factor: operator_fee_factor)
    end

    def initialize(
      rate_resolver: FCS::Application::ResolveFxRate.new(
        fx_provider: Admin::Fx::Adapters::RateResolverProvider.new
      ),
      context_normalizer: FCS::Application::NormalizeFxContext.new
    )
      @rate_resolver = rate_resolver
      @context_normalizer = context_normalizer
    end

    def call(run:, operator_fee_factor: nil)
      raise "Run#input_json is required" if run.input_json.blank?

      input = deep_copy(run.input_json)

      existing_context = input["fxContext"] || run.fx_context
      if existing_context.is_a?(Hash)
        input["fxContext"] ||= existing_context
        run.update!(input_json: input, fx_context: existing_context)
        return existing_context
      end

      reporting_currency = ReportingSetting.current.reporting_currency
      valuation_timestamp = input.dig("priceSnapshot", "valuationTimestamp")
      operational_date = Admin::Fx::OperationalDate.call(timestamp: valuation_timestamp)

      rate_data = @rate_resolver.call(
        base_currency: Admin::Fx::RateResolver::BASE_CURRENCY,
        quote_currency: reporting_currency,
        operational_date: operational_date
      )

      fx_context = @context_normalizer.call(
        reporting_currency: reporting_currency,
        operator_fee_factor: operator_fee_factor || FCS::Application::NormalizeFxContext::DEFAULT_OPERATOR_FEE_FACTOR,
        rate_data: rate_data,
        operational_date: operational_date
      )

      input["fxContext"] = fx_context
      run.update!(input_json: input, fx_context: fx_context)
      fx_context
    end

    private

    def deep_copy(data)
      JSON.parse(JSON.generate(data))
    end
  end
end
