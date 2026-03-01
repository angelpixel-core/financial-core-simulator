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
      field :result_json_link, as: :text, as_html: true, name: "result.json"
      field :positions_csv_link, as: :text, as_html: true, name: "positions.csv"
      field :pnl_csv_link, as: :text, as_html: true, name: "pnl.csv"
    end
  end

  def filters
    filter Avo::Filters::RunStatus
  end
end
