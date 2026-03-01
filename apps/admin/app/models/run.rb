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

  def result_json_url = Rails.application.routes.url_helpers.run_result_path(id: id)
  def positions_csv_url = Rails.application.routes.url_helpers.run_positions_path(id: id)
  def pnl_csv_url = Rails.application.routes.url_helpers.run_pnl_path(id: id)

  def result_json_link = artifact_link("View result.json", result_json_path, result_json_url)
  def positions_csv_link = artifact_link("Download positions.csv", positions_csv_path, positions_csv_url)
  def pnl_csv_link = artifact_link("Download pnl.csv", pnl_csv_path, pnl_csv_url)

  private

  def set_defaults
    self.status ||= :queued
  end

  def artifact_link(label, path, url)
    return "Unavailable" if path.blank?

    %(<a href="#{url}" target="_blank" rel="noopener">#{label}</a>)
  end
end
