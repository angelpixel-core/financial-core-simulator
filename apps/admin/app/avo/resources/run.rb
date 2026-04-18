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
          data: {turbo_method: :post},
          rel: "noopener"
        )
      end

      field :enqueue_run, as: :text, as_html: true, only_on: :show, name: "enqueue run" do
        view_context.link_to(
          "Enqueue execution",
          view_context.main_app.run_execute_path(id: record.id, async: 1),
          data: {turbo_method: :post},
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
          data: {turbo_method: :post},
          rel: "noopener"
        )
      end
    end

    panel "Reliability & Validation" do
      field :run_diagnostics, as: :text, as_html: true, only_on: :show, name: "diagnostics" do
        view_context.render(Admin::Runs::RunDiagnosticsPanelComponent.new(run: record))
      end
    end

    panel "Persisted operations" do
      field :persisted_operations_counts, as: :text, as_html: true, only_on: :show, name: "counts" do
        snapshots_count = record.run_snapshots.count
        events_count = record.run_daily_events.count
        volumes_count = record.run_daily_volumes.count
        pnl_count = record.run_daily_pnls.count

        <<~HTML.squish
          <div>
            <strong>Snapshots:</strong> #{snapshots_count} &nbsp;|&nbsp;
            <strong>Events:</strong> #{events_count} &nbsp;|&nbsp;
            <strong>Daily volumes:</strong> #{volumes_count} &nbsp;|&nbsp;
            <strong>Daily PnL:</strong> #{pnl_count}
          </div>
        HTML
      end

      field :run_snapshots, as: :has_many
      field :run_daily_events, as: :has_many
      field :run_daily_volumes, as: :has_many
      field :run_daily_pnls, as: :has_many
    end

    panel "Triage drilldown" do
      field :overview_drilldown, as: :text, as_html: true, only_on: :show, name: "overview" do
        context_params = Admin::Runs::NavigationContext.capture(params: view_context.request.query_parameters,
          run: record)
        view_context.link_to("Open admin overview", view_context.main_app.admin_overview_path(context_params),
          rel: "noopener")
      end

      field :top_accounts_drilldown, as: :text, as_html: true, only_on: :show, name: "top accounts" do
        context_params = Admin::Runs::NavigationContext.capture(params: view_context.request.query_parameters,
          run: record)
        view_context.link_to("Open top accounts",
          view_context.main_app.admin_overview_top_accounts_path(context_params), rel: "noopener")
      end

      field :ingestion_errors_drilldown, as: :text, as_html: true, only_on: :show, name: "ingestion errors" do
        context_params = Admin::Runs::NavigationContext.capture(params: view_context.request.query_parameters,
          run: record)
        view_context.link_to("Open ingestion validation errors",
          view_context.main_app.admin_overview_ingestion_validation_errors_path(context_params), rel: "noopener")
      end
    end

    panel "Artifacts viewer" do
      field :artifact_evidence, as: :text, as_html: true, only_on: :show, name: "artifact evidence" do
        context_params = Admin::Runs::NavigationContext.capture(params: view_context.request.query_parameters,
          run: record)
        view_context.render(Admin::Runs::ArtifactEvidencePanelComponent.new(run: record,
          context_params: context_params))
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
