module Admin
  module Runs
    class RunDiagnosticsPanelComponent < ViewComponent::Base
      def initialize(run:, validation_diagnostics: Admin::Runs::RunValidationDiagnostics.new, reliability_diagnostics: Admin::Runs::RunReliabilityDiagnostics.new)
        @run = run
        @validation_diagnostics = validation_diagnostics
        @reliability_diagnostics = reliability_diagnostics
      end

      def reliability
        @reliability ||= @reliability_diagnostics.call(run: @run)
      end

      def validation
        @validation ||= @validation_diagnostics.call(run: @run)
      end
    end
  end
end
