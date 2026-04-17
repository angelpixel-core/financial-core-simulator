# frozen_string_literal: true

class RunSnapshot < ApplicationRecord
  belongs_to :run
  has_one :run_daily_pnl, dependent: :destroy
  has_one :run_daily_volume, dependent: :destroy
  has_many :run_daily_events, dependent: :destroy

  validates :run_id, presence: true
  validates :operational_date, presence: true
  validates :reporting_currency, presence: true
  validates :operational_date, uniqueness: { scope: %i[run_id reporting_currency] }

  scope :timeline_ordered, -> { order(:operational_date, :id) }

  scope :for_timeline_eligible_runs, lambda { |up_to_run_id: nil, reporting_currency: nil, run_ids: nil|
    eligible_runs = Run.timeline_eligible
    eligible_runs = eligible_runs.where(id: run_ids) if run_ids.present?
    eligible_runs = eligible_runs.where('runs.id <= ?', up_to_run_id.to_i) if up_to_run_id.present?

    scope = where(run_id: eligible_runs.select(:id))
    scope = scope.where(reporting_currency: reporting_currency) if reporting_currency.present?

    scope.includes(:run_daily_pnl, :run_daily_volume).timeline_ordered
  }
end
