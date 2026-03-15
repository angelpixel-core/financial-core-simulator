module Admin
  module Runs
    class ReliableRunSelector
      Result = Struct.new(:reliable_run, :candidate_run, :state, :diagnostic, keyword_init: true)

      def call
        reliable = latest_verified_run
        return reliable_result(reliable) if reliable.present?

        degraded_result
      end

      private

      def latest_verified_run
        Run.succeeded.where(verification_status: Run.verification_statuses.fetch("verified")).order(id: :desc).first
      end

      def latest_successful_run
        Run.succeeded.order(id: :desc).first
      end

      def latest_run
        Run.order(id: :desc).first
      end

      def reliable_result(run)
        Result.new(
          reliable_run: run,
          candidate_run: run,
          state: :reliable,
          diagnostic: {
            what_happened: "Run verificado y confiable disponible.",
            impact: "El flujo de inspeccion puede continuar sin restricciones.",
            next_action: "Abrir el run y revisar PnL, validacion y artifacts."
          }
        )
      end

      def degraded_result
        candidate = latest_successful_run || latest_run

        Result.new(
          reliable_run: nil,
          candidate_run: candidate,
          state: :degraded,
          diagnostic: degraded_diagnostic(candidate)
        )
      end

      def degraded_diagnostic(candidate)
        return no_run_diagnostic if candidate.nil?

        if candidate.verification_status == "verified"
          default_degraded_diagnostic
        else
          unverified_diagnostic(candidate)
        end
      end

      def no_run_diagnostic
        {
          what_happened: "No hay runs disponibles todavia.",
          impact: "No es posible identificar un run confiable en este momento.",
          next_action: "Ejecuta un run de prueba y vuelve a cargar el overview."
        }
      end

      def unverified_diagnostic(candidate)
        status_label = candidate.status.to_s.tr("_", " ")
        verification_label = candidate.verification_status.to_s.tr("_", " ")

        {
          what_happened: "El ultimo run exitoso no tiene verificacion confiable.",
          impact: "La inspeccion se muestra en modo degradado porque la validacion aun no confirma confiabilidad.",
          next_action: "Revisa el run ##{candidate.id} (estado #{status_label}, " \
                       "verificacion #{verification_label}) y ejecuta verificacion de hash."
        }
      end

      def default_degraded_diagnostic
        {
          what_happened: "No se encontro un run confiable vigente.",
          impact: "La seleccion automatica esta degradada.",
          next_action: "Verifica el ultimo run exitoso o abre la lista completa de runs."
        }
      end
    end
  end
end
