module Admin
  module Runs
    class RunValidationDiagnostics
      def initialize(validation_error_repository: Admin::Runs::ValidationErrors::Repository.new)
        @validation_error_repository = validation_error_repository
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
        return :warning if run.status.to_s == 'failed'
        return :loading if %w[queued running].include?(run.status.to_s)

        :success
      end

      def diagnostic_for(_run, state)
        case state
        when :error
          {
            what_happened: I18n.t('admin.runs.validation_diagnostics.error.what_happened'),
            impact: I18n.t('admin.runs.validation_diagnostics.error.impact'),
            next_action: I18n.t('admin.runs.validation_diagnostics.error.next_action')
          }
        when :warning
          {
            what_happened: I18n.t('admin.runs.validation_diagnostics.warning.what_happened'),
            impact: I18n.t('admin.runs.validation_diagnostics.warning.impact'),
            next_action: I18n.t('admin.runs.validation_diagnostics.warning.next_action')
          }
        when :loading
          {
            what_happened: I18n.t('admin.runs.validation_diagnostics.loading.what_happened'),
            impact: I18n.t('admin.runs.validation_diagnostics.loading.impact'),
            next_action: I18n.t('admin.runs.validation_diagnostics.loading.next_action')
          }
        else
          {
            what_happened: I18n.t('admin.runs.validation_diagnostics.success.what_happened'),
            impact: I18n.t('admin.runs.validation_diagnostics.success.impact'),
            next_action: I18n.t('admin.runs.validation_diagnostics.success.next_action')
          }
        end
      end

      def validation_error?(run)
        @validation_error_repository.validation_error?(run: run)
      end

      def issues_for(run)
        return [] if run.nil?

        @validation_error_repository.issues_for(run: run)
      end
    end
  end
end
