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
    end
  end

  def filters
    filter Avo::Filters::RunStatus
    filter Avo::Filters::RunInputHash
  end
end
