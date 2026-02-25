# frozen_string_literal: true

class Run < ApplicationRecord
  enum :status, {
    queued: 0,
    running: 1,
    succeeded: 2,
    failed: 3
  }

  validates :status, presence: true
  validates :run_uuid, uniqueness: true, allow_nil: true

  before_validation :set_defaults, on: :create

  def result_json_path = artifacts&.dig("result_json_path")
  def positions_csv_path = artifacts&.dig("positions_csv_path")
  def pnl_csv_path = artifacts&.dig("pnl_csv_path")

  private

  def set_defaults
    self.status ||= :queued
  end
end
