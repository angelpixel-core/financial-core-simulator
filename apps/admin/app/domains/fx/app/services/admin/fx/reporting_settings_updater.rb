# frozen_string_literal: true

module Admin
  module Fx
    class ReportingSettingsUpdater
      def self.call(reporting_currency:, updated_by_id: nil, updated_by_role: nil, updated_context: {})
        new.call(
          reporting_currency: reporting_currency,
          updated_by_id: updated_by_id,
          updated_by_role: updated_by_role,
          updated_context: updated_context
        )
      end

      def call(reporting_currency:, updated_by_id: nil, updated_by_role: nil, updated_context: {})
        setting = ReportingSetting.current
        setting.update!(
          reporting_currency: reporting_currency,
          updated_by_id: updated_by_id,
          updated_by_role: updated_by_role,
          updated_context: updated_context
        )
        setting
      end
    end
  end
end
