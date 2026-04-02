# frozen_string_literal: true

class RunSnapshot < ApplicationRecord
  belongs_to :run
  has_one :run_daily_pnl, dependent: :destroy
  has_one :run_daily_volume, dependent: :destroy
  has_many :run_daily_events, dependent: :destroy

  validates :run_id, presence: true
  validates :operational_date, presence: true
  validates :reporting_currency, presence: true
  validates :operational_date, uniqueness: {scope: %i[run_id reporting_currency]}
end
