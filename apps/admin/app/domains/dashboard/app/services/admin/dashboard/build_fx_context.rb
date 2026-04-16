# frozen_string_literal: true

module Admin
  module Dashboard
    class BuildFxContext
      def initialize(
        daily_rate_repository: Admin::Dashboard::Repositories::ActiveRecord::FxDailyRateRepository.new,
        reporting_setting_reader: -> { ReportingSetting.current }
      )
        @daily_rate_repository = daily_rate_repository
        @reporting_setting_reader = reporting_setting_reader
      end

      def call
        reporting_setting = @reporting_setting_reader.call
        operational_date = Admin::Fx::OperationalDate.call
        base_currency = Admin::Fx::RateResolver::BASE_CURRENCY
        quote_currency = reporting_setting.reporting_currency

        if quote_currency == base_currency
          return {
            reporting_setting: reporting_setting,
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency,
            rate_state: Admin::Fx::RateResolver::Result.new(
              rate: "1.0",
              rate_date: operational_date,
              rate_source: Admin::Fx::RateResolver::IDENTITY_SOURCE,
              rate_missing: false,
              source_rate_id: nil
            ),
            carry_forward_available: false
          }
        end

        rate_state = Admin::Fx::RateResolver.call(
          base_currency: base_currency,
          quote_currency: quote_currency,
          operational_date: operational_date
        )

        carry_forward_available = @daily_rate_repository.exists_for_date?(
          operational_date: operational_date - 1.day,
          base_currency: base_currency,
          quote_currency: quote_currency
        )

        {
          reporting_setting: reporting_setting,
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate_state: rate_state,
          carry_forward_available: carry_forward_available
        }
      end
    end
  end
end
