# frozen_string_literal: true

class Avo::Resources::RunDailyVolume < Avo::BaseResource
  self.title = :id
  self.includes = [{ run_snapshot: :run }]

  def fields
    field :id, as: :id
    field :run_snapshot, as: :belongs_to
    field :notional_volume, as: :number
    field :trade_count, as: :number
    field :unit_type, as: :text
    field :unit_code, as: :text
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
