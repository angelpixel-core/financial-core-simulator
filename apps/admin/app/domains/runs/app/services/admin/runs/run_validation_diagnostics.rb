module Admin
  module Runs
    class RunValidationDiagnostics
      VALIDATION_ERROR_CODES = Admin::DashboardMetrics::VALIDATION_ERROR_CODES

      def initialize(error_mapper: Admin::Dashboard::IngestionValidationErrorMapper.new)
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

      def diagnostic_for(run, state)
        case state
        when :error
          {
            what_happened: "La validacion de datos del run fallo.",
            impact: "Los resultados no son confiables para decisiones financieras.",
            next_action: "Revisa los issues, corrige el input y re-ejecuta el run."
          }
        when :warning
          {
            what_happened: "La validacion no pudo completarse por una falla del run.",
            impact: "No es posible confirmar la calidad de datos en este estado.",
            next_action: "Revisa el error de ejecucion y vuelve a intentar el run."
          }
        when :loading
          {
            what_happened: "El run sigue en ejecucion.",
            impact: "La validacion aun no esta disponible.",
            next_action: "Espera la finalizacion y vuelve a cargar el detalle."
          }
        else
          {
            what_happened: "La validacion no reporta issues.",
            impact: "Los datos son consistentes para inspeccion operativa.",
            next_action: "Continuar con PnL y revisar artifacts si hace falta."
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
