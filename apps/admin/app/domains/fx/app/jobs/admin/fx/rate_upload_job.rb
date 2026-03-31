# frozen_string_literal: true

class Admin::Fx::RateUploadJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    upload = FxRateUpload.find(upload_id)
    result = Admin::Fx::RateUploadImporter.call(
      file_path: upload.file_path,
      created_by_id: upload.created_by_id,
      created_by_role: upload.created_by_role,
      created_context: upload.created_context,
      source_upload_id: upload.id
    )

    if result.valid?
      upload.update!(
        status: 'success',
        error_count: 0,
        error_message: nil,
        processed_at: Time.current
      )
    else
      upload.update!(
        status: 'error',
        error_count: result.errors.size,
        error_message: result.errors.first&.dig(:message),
        processed_at: Time.current
      )
    end
  rescue StandardError => e
    if upload
      upload.update!(
        status: 'error',
        error_count: [upload.error_count.to_i, 1].max,
        error_message: e.message,
        processed_at: Time.current
      )
    end
  ensure
    cleanup_file(upload&.file_path)
    broadcast_status(upload) if upload
  end

  private

  def cleanup_file(file_path)
    return if file_path.blank?

    File.delete(file_path) if File.exist?(file_path)
  end

  def broadcast_status(upload)
    Turbo::StreamsChannel.broadcast_replace_to(
      FxRateUpload.status_stream_for(account_id: upload.created_by_id),
      target: FxRateUpload.status_dom_id,
      partial: 'admin/fx/history/upload_status',
      locals: { upload: upload }
    )
  end
end
