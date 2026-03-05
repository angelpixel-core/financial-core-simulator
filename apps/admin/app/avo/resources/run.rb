# frozen_string_literal: true

class Avo::Resources::Run < Avo::BaseResource
  self.title = :id
  self.includes = []

  def fields
    field :id, as: :id

    field :status, as: :select, enum: ::Run.statuses
    field :run_uuid, as: :text
    field :input_hash, as: :text

    field :engine_version, as: :text
    field :schema_version, as: :text

    field :valuation_timestamp, as: :date_time
    field :duration_ms, as: :number

    field :output_dir, as: :text
    field :artifacts, as: :key_value

    field :error_code, as: :text
    field :error_message, as: :textarea

    panel "Execution" do
      field :execute_run, as: :text, as_html: true, only_on: :show, name: "execute run" do
        view_context.link_to(
          "Execute now",
          view_context.main_app.run_execute_path(id: record.id),
          data: { turbo_method: :post },
          rel: "noopener"
        )
      end

      field :enqueue_run, as: :text, as_html: true, only_on: :show, name: "enqueue run" do
        view_context.link_to(
          "Enqueue execution",
          view_context.main_app.run_execute_path(id: record.id, async: 1),
          data: { turbo_method: :post },
          rel: "noopener"
        )
      end
    end

    panel "Verification" do
      field :verification_status, as: :badge,
        options: {
          unverified: :warning,
          verified: :success,
          mismatch: :danger,
          verification_error: :danger
        }
      field :verified_at, as: :date_time
      field :verification_input_hash, as: :text
      field :verification_error, as: :textarea
      field :verify_input_hash, as: :text, as_html: true, only_on: :show, name: "verify input hash" do
        view_context.link_to(
          "Verify now",
          view_context.main_app.run_verify_path(id: record.id),
          data: { turbo_method: :post },
          rel: "noopener"
        )
      end
    end

    panel "Triage drilldown" do
      field :overview_drilldown, as: :text, as_html: true, only_on: :show, name: "overview" do
        view_context.link_to("Open admin overview", view_context.main_app.admin_overview_path, rel: "noopener")
      end

      field :top_accounts_drilldown, as: :text, as_html: true, only_on: :show, name: "top accounts" do
        view_context.link_to("Open top accounts", view_context.main_app.admin_overview_top_accounts_path, rel: "noopener")
      end

      field :ingestion_errors_drilldown, as: :text, as_html: true, only_on: :show, name: "ingestion errors" do
        view_context.link_to("Open ingestion validation errors", view_context.main_app.admin_overview_ingestion_validation_errors_path, rel: "noopener")
      end
    end

    panel "Artifacts viewer" do
      field :result_download, as: :text, as_html: true, only_on: :show, name: "result.json" do
        next "Unavailable" if record.result_json_path.blank?

        view_context.link_to("View result.json", view_context.main_app.run_result_path(id: record.id), target: "_blank", rel: "noopener")
      end

      field :positions_preview, as: :text, as_html: true, only_on: :show, name: "positions preview" do
        next "Unavailable" if record.positions_csv_path.blank?

        view_context.link_to("Preview positions.csv", view_context.main_app.run_positions_path(id: record.id, preview: 1), target: "_blank", rel: "noopener")
      end

      field :positions_download, as: :text, as_html: true, only_on: :show, name: "positions.csv" do
        next "Unavailable" if record.positions_csv_path.blank?

        view_context.link_to("Download positions.csv", view_context.main_app.run_positions_path(id: record.id), target: "_blank", rel: "noopener")
      end

      field :pnl_preview, as: :text, as_html: true, only_on: :show, name: "pnl preview" do
        next "Unavailable" if record.pnl_csv_path.blank?

        view_context.link_to("Preview pnl.csv", view_context.main_app.run_pnl_path(id: record.id, preview: 1), target: "_blank", rel: "noopener")
      end

      field :pnl_download, as: :text, as_html: true, only_on: :show, name: "pnl.csv" do
        next "Unavailable" if record.pnl_csv_path.blank?

        view_context.link_to("Download pnl.csv", view_context.main_app.run_pnl_path(id: record.id), target: "_blank", rel: "noopener")
      end

      field :risk_view, as: :text, as_html: true, only_on: :show, name: "risk view" do
        next "Unavailable" if record.result_json_path.blank?

        view_context.link_to("Open risk view", view_context.main_app.run_risk_path(id: record.id), target: "_blank", rel: "noopener")
      end
    end
  end

  def filters
    filter Avo::Filters::RunGlobalSearch
    filter Avo::Filters::RunSearchPreset
    filter Avo::Filters::RunStatus
    filter Avo::Filters::RunInputHash
    filter Avo::Filters::RunUuid
  end
end
