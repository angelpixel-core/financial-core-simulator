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
            label: I18n.t("admin.runs.artifacts.entries.result_json.label"),
            description: I18n.t("admin.runs.artifacts.entries.result_json.description"),
            state: status_for(:result_json_path),
            actions: [action(I18n.t("admin.runs.artifacts.entries.result_json.action"), :run_result_path,
              :result_json_path)]
          ),
          ArtifactEntry.new(
            label: I18n.t("admin.runs.artifacts.entries.positions_preview.label"),
            description: I18n.t("admin.runs.artifacts.entries.positions_preview.description"),
            state: status_for(:positions_csv_path),
            actions: [action(I18n.t("admin.runs.artifacts.entries.positions_preview.action"), :run_positions_path,
              :positions_csv_path, preview: 1)]
          ),
          ArtifactEntry.new(
            label: I18n.t("admin.runs.artifacts.entries.positions_download.label"),
            description: I18n.t("admin.runs.artifacts.entries.positions_download.description"),
            state: status_for(:positions_csv_path),
            actions: [action(I18n.t("admin.runs.artifacts.entries.positions_download.action"), :run_positions_path,
              :positions_csv_path)]
          ),
          ArtifactEntry.new(
            label: I18n.t("admin.runs.artifacts.entries.pnl_preview.label"),
            description: I18n.t("admin.runs.artifacts.entries.pnl_preview.description"),
            state: status_for(:pnl_csv_path),
            actions: [action(I18n.t("admin.runs.artifacts.entries.pnl_preview.action"), :run_pnl_path, :pnl_csv_path,
              preview: 1)]
          ),
          ArtifactEntry.new(
            label: I18n.t("admin.runs.artifacts.entries.risk_view.label"),
            description: I18n.t("admin.runs.artifacts.entries.risk_view.description"),
            state: status_for(:result_json_path),
            actions: [action(I18n.t("admin.runs.artifacts.entries.risk_view.action"), :run_risk_path,
              :result_json_path)]
          )
        ]
      end

      def provenance_rows
        [
          [I18n.t("admin.runs.artifacts.provenance.run_id"), @run.id],
          [I18n.t("admin.runs.artifacts.provenance.input_hash"), @run.input_hash.presence || I18n.t("admin.common.na")],
          [I18n.t("admin.runs.artifacts.provenance.timestamp_utc"), timestamp_utc],
          [I18n.t("admin.runs.artifacts.provenance.version"), version_label]
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

      def status_label(state)
        case state
        when :complete then I18n.t("admin.runs.artifacts.status.complete")
        when :partial then I18n.t("admin.runs.artifacts.status.partial")
        else I18n.t("admin.runs.artifacts.status.unavailable")
        end
      end

      private

      def action(label, helper_name, attribute, extra_params = {})
        return {label: label, href: nil} if resolved_path_for(attribute).nil?

        params = @context_params.merge(extra_params)
        {label: label, href: route_path(helper_name, {id: @run.id}.merge(params))}
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

      def route_path(helper_name, params)
        return helpers.public_send(helper_name, params) if helpers.respond_to?(helper_name)

        helpers.main_app.public_send(helper_name, params)
      end

      def timestamp_utc
        timestamp = @run.valuation_timestamp || @run.created_at
        return I18n.t("admin.common.na") if timestamp.blank?

        timestamp.utc.iso8601
      end

      def version_label
        engine = @run.engine_version.presence || I18n.t("admin.common.na")
        schema = @run.schema_version.presence || I18n.t("admin.common.na")
        I18n.t("admin.runs.artifacts.version", engine: engine, schema: schema)
      end
    end
  end
end
