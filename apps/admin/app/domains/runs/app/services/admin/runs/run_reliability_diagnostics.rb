module Admin
  module Runs
    class RunReliabilityDiagnostics
      def call(run:)
        state = state_for(run)

        {
          state: state,
          title: "Estado de confiabilidad",
          diagnostic: diagnostic_for(run, state)
        }
      end

      private

      def state_for(run)
        return :loading if run.nil?

        status = run.status.to_s
        verification = run.verification_status.to_s

        return :loading if %w[queued running].include?(status)
        return :reliable if status == "succeeded" && verification == "verified"

        :degraded
      end

      def diagnostic_for(run, state)
        case state
        when :reliable
          {
            what_happened: "Run verificado y confiable.",
            impact: "El detalle puede inspeccionarse sin restricciones.",
            next_action: "Continuar con validacion y artifacts del run."
          }
        when :loading
          {
            what_happened: "El run sigue en ejecucion.",
            impact: "La confiabilidad aun no puede confirmarse.",
            next_action: "Espera la finalizacion y vuelve a abrir el detalle."
          }
        else
          status_label = run&.status.to_s.tr("_", " ")
          verification_label = run&.verification_status.to_s.tr("_", " ")

          {
            what_happened: "El run no cumple con criterios de confiabilidad.",
            impact: "La inspeccion se muestra en modo degradado.",
            next_action: "Revisa estado #{status_label} y verificacion #{verification_label}, " \
                         "luego valida hash o re-ejecuta."
          }
        end
      end
    end
  end
end
