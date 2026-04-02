# frozen_string_literal: true

class DemoDatasetUpload < ApplicationRecord
  enum :status, {
    valid: "valid",
    invalid: "invalid"
  }, suffix: true, validate: true

  scope :latest_first, -> { order(created_at: :desc) }

  def self.latest
    latest_first.first
  end
end
