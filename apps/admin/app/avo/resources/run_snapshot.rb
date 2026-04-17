# frozen_string_literal: true

class Avo::Resources::RunSnapshot < Avo::BaseResource
  self.title = :id
  self.includes = %i[run run_daily_volume run_daily_pnl]

  def fields
    field :id, as: :id
    field :run, as: :belongs_to
    field :operational_date, as: :date
    field :reporting_currency, as: :text
    field :run_daily_volume, as: :has_one
    field :run_daily_pnl, as: :has_one
    field :run_daily_events, as: :has_many
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
