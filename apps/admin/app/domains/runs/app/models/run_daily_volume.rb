# frozen_string_literal: true

class RunDailyVolume < ApplicationRecord
  belongs_to :run_snapshot

  validates :run_snapshot_id, presence: true
  validates :notional_volume, presence: true
  validates :trade_count, presence: true
  validates :unit_type, presence: true
  validates :unit_code, presence: true
  validates :run_snapshot_id, uniqueness: true
end
