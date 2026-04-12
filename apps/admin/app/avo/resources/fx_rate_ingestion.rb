# frozen_string_literal: true

class Avo::Resources::FxRateIngestion < Avo::BaseResource
  self.title = :id
  self.includes = [:source]

  def fields
    field :id, as: :id
    field :source, as: :belongs_to
    field :status, as: :select, options: FxRateIngestion::STATUSES
    field :error_code, as: :text
    field :context, as: :key_value
    field :metadata, as: :key_value
    field :correlation_id, as: :text
    field :causation_id, as: :text
    field :started_at, as: :date_time
    field :finished_at, as: :date_time
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
