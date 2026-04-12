# frozen_string_literal: true

class Avo::Resources::FxRateEvent < Avo::BaseResource
  self.title = :event_type
  self.includes = []

  def fields
    field :id, as: :id
    field :event_id, as: :text
    field :event_type, as: :text
    field :data, as: :key_value
    field :metadata, as: :key_value
    field :created_at, as: :date_time
  end
end
