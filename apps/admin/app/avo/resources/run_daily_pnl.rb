# frozen_string_literal: true

class Avo::Resources::RunDailyPnl < Avo::BaseResource
  self.title = :id
  self.includes = [{ run_snapshot: :run }]

  def fields
    field :id, as: :id
    field :run_snapshot, as: :belongs_to
    field :realized_pnl, as: :number
    field :unrealized_pnl, as: :number
    field :total_pnl, as: :number
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
