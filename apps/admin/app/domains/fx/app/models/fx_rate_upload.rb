# frozen_string_literal: true

class FxRateUpload < ApplicationRecord
  STATUS_VISIBILITY_WINDOW = 30.minutes

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

  def self.table_dom_id
    'fx-rate-history-table'
  end

  def self.visible_for(account_id: nil, within: STATUS_VISIBILITY_WINDOW)
    upload = latest_for(account_id: account_id)
    return if upload.blank?

    last_activity = upload.processed_at || upload.created_at
    return upload if within.blank? || last_activity.blank?
    return if last_activity < Time.current - within

    upload
  end

  def self.visible_for_upload(upload_id:, account_id: nil, within: STATUS_VISIBILITY_WINDOW)
    return if upload_id.blank?

    scope = where(id: upload_id)
    scope = scope.where(created_by_id: account_id.to_s) if account_id.present?
    upload = scope.first
    return if upload.blank?

    last_activity = upload.processed_at || upload.created_at
    return upload if within.blank? || last_activity.blank?
    return if last_activity < Time.current - within

    upload
  end
end
