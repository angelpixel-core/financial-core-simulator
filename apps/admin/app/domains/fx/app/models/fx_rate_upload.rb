# frozen_string_literal: true

class FxRateUpload < ApplicationRecord
  enum :status, {
    processing: 'processing',
    success: 'success',
    error: 'error'
  }, suffix: true, validate: true

  scope :latest_first, -> { order(created_at: :desc) }

  def self.latest_for(account_id: nil)
    return latest_first.first if account_id.blank?

    latest_first.find_by(created_by_id: account_id.to_s)
  end

  def self.status_stream_for(account_id: nil)
    "fx_rate_upload_status:#{account_id.presence || 'guest'}"
  end

  def self.status_dom_id
    'fx-rate-upload-status'
  end
end
