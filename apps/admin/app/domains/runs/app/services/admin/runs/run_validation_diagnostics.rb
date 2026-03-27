module Admin
  module Runs
    class RunValidationDiagnostics
      VALIDATION_ERROR_CODES = [
        ::Runs::ErrorCodeMapper::VALIDATION_GENERAL,
        ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
        ::Runs::ErrorCodeMapper::VALIDATION_RISK,
        ::Runs::ErrorCodeMapper::VALIDATION_COLLATERAL,
        ::Runs::ErrorCodeMapper::VALIDATION_TRADE_DECIMAL,
        ::Runs::ErrorCodeMapper::VALIDATION_UNKNOWN_REFERENCE,
        ::Runs::ErrorCodeMapper::VALIDATION_DUPLICATE_SEQ,
        ::Runs::ErrorCodeMapper::VALIDATION_INVALID_NUMBER
      ].freeze

      def initialize(error_mapper: Admin::Validation::IngestionValidationErrorMapper.new)
        @error_mapper = error_mapper
      end

      def call(run:)
        state = state_for(run)

        {
          state: state,
          diagnostic: diagnostic_for(run, state),
          issues: issues_for(run)
        }
      end

      private

      def state_for(run)
        return :loading if run.nil?
        return :error if validation_error?(run)
        return :warning if run.status.to_s == "failed"
        return :loading if %w[queued running].include?(run.status.to_s)

        :success
      end

      def diagnostic_for(_run, state)
        case state
        when :error
          {
            what_happened: I18n.t("admin.runs.validation_diagnostics.error.what_happened"),
            impact: I18n.t("admin.runs.validation_diagnostics.error.impact"),
            next_action: I18n.t("admin.runs.validation_diagnostics.error.next_action")
          }
        when :warning
          {
            what_happened: I18n.t("admin.runs.validation_diagnostics.warning.what_happened"),
            impact: I18n.t("admin.runs.validation_diagnostics.warning.impact"),
            next_action: I18n.t("admin.runs.validation_diagnostics.warning.next_action")
          }
        when :loading
          {
            what_happened: I18n.t("admin.runs.validation_diagnostics.loading.what_happened"),
            impact: I18n.t("admin.runs.validation_diagnostics.loading.impact"),
            next_action: I18n.t("admin.runs.validation_diagnostics.loading.next_action")
          }
        else
          {
            what_happened: I18n.t("admin.runs.validation_diagnostics.success.what_happened"),
            impact: I18n.t("admin.runs.validation_diagnostics.success.impact"),
            next_action: I18n.t("admin.runs.validation_diagnostics.success.next_action")
          }
        end
      end

      def issues_for(run)
        return [] if run.nil?
        return [] unless validation_error?(run)

        entry = @error_mapper.map(run: run)
        [
          entry.merge(severity: "error")
        ]
      end

      def validation_error?(run)
        return false if run.nil?

        VALIDATION_ERROR_CODES.include?(run.error_code)
      end
    end
  end
end
