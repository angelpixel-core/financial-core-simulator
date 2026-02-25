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
      # Estos 3 son métodos del modelo Run, no dependen de blocks ni de Avo context.
      field :result_json_path, as: :text, name: "result.json"
      field :positions_csv_path, as: :text, name: "positions.csv"
      field :pnl_csv_path, as: :text, name: "pnl.csv"
    end
  end

  def filters
    filter Avo::Filters::RunStatus
  end
end
