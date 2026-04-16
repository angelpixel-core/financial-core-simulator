# frozen_string_literal: true

require 'bigdecimal'

module Admin
  module Fx
    class RateResolver
      BASE_CURRENCY = 'USD'
      IDENTITY_SOURCE = 'identity'

      Result = Struct.new(
        :rate,
        :rate_date,
        :rate_source,
        :rate_missing,
        :source_rate_id,
        keyword_init: true
      )

      def self.call(base_currency:, quote_currency:, operational_date:)
        new.call(
          base_currency: base_currency,
          quote_currency: quote_currency,
          operational_date: operational_date
        )
      end

      def initialize(rate_repository: Admin::Fx::Rates::Repository.new)
        @rate_repository = rate_repository
      end

      def call(base_currency:, quote_currency:, operational_date:)
        base = base_currency.to_s.upcase
        quote = quote_currency.to_s.upcase

        if base == quote || quote.empty?
          return Result.new(
            rate: '1.0',
            rate_date: operational_date,
            rate_source: IDENTITY_SOURCE,
            rate_missing: false,
            source_rate_id: nil
          )
        end

        rate = @rate_repository.find_by(
          operational_date: operational_date,
          base_currency: base,
          quote_currency: quote
        )

        if rate.nil?
          return Result.new(
            rate: nil,
            rate_date: operational_date,
            rate_source: nil,
            rate_missing: true,
            source_rate_id: nil
          )
        end

        if rate.rate.nil? || rate.source == 'placeholder'
          return Result.new(
            rate: nil,
            rate_date: rate.operational_date,
            rate_source: rate.source,
            rate_missing: true,
            source_rate_id: nil
          )
        end

        Result.new(
          rate: decimal_string(rate.rate),
          rate_date: rate.operational_date,
          rate_source: rate.source,
          rate_missing: false,
          source_rate_id: rate.source_rate_id
        )
      end

      private

      def decimal_string(value)
        return value.to_s('F') if value.is_a?(BigDecimal)

        value.to_s
      end
    end
  end
end
