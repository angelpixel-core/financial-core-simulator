# frozen_string_literal: true

module Admin
  module Fx
    class ReportingCurrencyFormComponent < ViewComponent::Base
      def initialize(reporting_setting:, supported_currencies:)
        @reporting_setting = reporting_setting
        @supported_currencies = supported_currencies
      end

      attr_reader :reporting_setting, :supported_currencies
    end
  end
end
