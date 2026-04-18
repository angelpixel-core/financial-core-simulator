# frozen_string_literal: true

class DemoDatasetUpload < ApplicationRecord
  enum :status, {
    valid: "valid",
    invalid: "invalid"
  }, suffix: true, validate: true

  before_validation :normalize_filename_fields

  validates :original_filename, presence: true
  validates :normalized_filename, presence: true, uniqueness: true

  scope :latest_first, -> { order(created_at: :desc) }
  scope :with_processed_run, -> { where.not(run_id: nil).where.not(original_filename: [nil, ""]) }

  def self.latest
    latest_first.first
  end

  def self.normalize_filename(value)
    normalized = File.basename(value.to_s).strip.downcase
    normalized.presence
  end

  private

  def normalize_filename_fields
    self.original_filename = File.basename(original_filename.to_s).strip.presence
    self.normalized_filename = self.class.normalize_filename(original_filename)
  end
end
