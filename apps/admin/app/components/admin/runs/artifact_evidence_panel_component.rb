module Admin
  module Runs
    class ArtifactEvidencePanelComponent < ViewComponent::Base
      ArtifactEntry = Struct.new(:label, :description, :state, :actions, keyword_init: true)

      def initialize(run:, context_params: {})
        @run = run
        @context_params = context_params.symbolize_keys
      end

      def entries
        @entries ||= [
          ArtifactEntry.new(
            label: "Resultado canonico (JSON)",
            description: "Contrato principal de salida para trazabilidad y reconciliacion.",
            state: status_for(:result_json_path),
            actions: [ action("Abrir result.json", :run_result_path, :result_json_path) ]
          ),
          ArtifactEntry.new(
            label: "Preview de posiciones",
            description: "Vista operativa de posiciones proyectadas por mercado/account.",
            state: status_for(:positions_csv_path),
            actions: [ action("Abrir preview positions.csv", :run_positions_path, :positions_csv_path, preview: 1) ]
          ),
          ArtifactEntry.new(
            label: "Descarga de posiciones",
            description: "Export CSV para auditoria y analisis externo.",
            state: status_for(:positions_csv_path),
            actions: [ action("Descargar positions.csv", :run_positions_path, :positions_csv_path) ]
          ),
          ArtifactEntry.new(
            label: "Preview de PnL",
            description: "Vista operativa del consolidado de PnL por run.",
            state: status_for(:pnl_csv_path),
            actions: [ action("Abrir preview pnl.csv", :run_pnl_path, :pnl_csv_path, preview: 1) ]
          ),
          ArtifactEntry.new(
            label: "Vista de riesgo",
            description: "Drilldown por estado de riesgo, eventos y margen.",
            state: status_for(:result_json_path),
            actions: [ action("Abrir risk view", :run_risk_path, :result_json_path) ]
          )
        ]
      end

      def provenance_rows
        [
          [ "run_id", @run.id ],
          [ "input_hash", @run.input_hash.presence || "n/a" ],
          [ "timestamp_utc", timestamp_utc ],
          [ "version", version_label ]
        ]
      end

      def status_badge_class(state)
        "artifact-evidence-panel__status artifact-evidence-panel__status--#{state}"
      end

      def status_icon(state)
        case state
        when :complete then "OK"
        when :partial then "~"
        else "!"
        end
      end

      private

      def action(label, helper_name, attribute, extra_params = {})
        return { label: label, href: nil } if resolved_path_for(attribute).nil?

        params = @context_params.merge(extra_params)
        { label: label, href: helpers.public_send(helper_name, { id: @run.id }.merge(params)) }
      end

      def status_for(attribute)
        return :unavailable if resolved_path_for(attribute).nil?
        return :partial if @run.input_hash.blank?

        :complete
      end

      def resolved_path_for(attribute)
        @resolved_paths ||= {}
        @resolved_paths[attribute] ||= Artifacts::PathResolver.new(run: @run, attribute: attribute).call
      end

      def timestamp_utc
        timestamp = @run.valuation_timestamp || @run.created_at
        return "n/a" if timestamp.blank?

        timestamp.utc.iso8601
      end

      def version_label
        engine = @run.engine_version.presence || "n/a"
        schema = @run.schema_version.presence || "n/a"
        "engine #{engine} / schema #{schema}"
      end
    end
  end
end
