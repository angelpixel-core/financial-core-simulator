# frozen_string_literal: true

class Avo::Resources::RunDailyEvent < Avo::BaseResource
  self.title = :id
  self.includes = [{run_snapshot: :run}]

  def fields
    field :id, as: :id
    field :run_snapshot, as: :belongs_to
    field :event_seq, as: :number
    field :event_type, as: :text
    field :payload, as: :key_value
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
