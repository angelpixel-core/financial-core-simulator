# frozen_string_literal: true

class RunDailyPnl < ApplicationRecord
  belongs_to :run_snapshot

  validates :run_snapshot_id, presence: true
  validates :realized_pnl, presence: true
  validates :unrealized_pnl, presence: true
  validates :total_pnl, presence: true
  validates :run_snapshot_id, uniqueness: true
end
