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
        status: "success",
        error_count: 0,
        error_message: result.message,
        processed_at: Time.current
      )
    else
      upload.update!(
        status: "error",
        error_count: result.errors.size,
        error_message: result.errors.first&.dig(:message),
        processed_at: Time.current
      )
    end
  rescue => e
    upload&.update!(
      status: "error",
      error_count: [upload.error_count.to_i, 1].max,
      error_message: e.message,
      processed_at: Time.current
    )
  ensure
    cleanup_file(upload&.file_path)
    broadcast_status(upload) if upload
    broadcast_table(upload) if upload
  end

  private

  def cleanup_file(file_path)
    return if file_path.blank?

    File.delete(file_path) if File.exist?(file_path)
  end

  def broadcast_status(upload)
    upload = FxRateUpload.find_by(id: upload.id)
    return if upload.blank?

    I18n.with_locale(locale_for(upload)) do
      Turbo::StreamsChannel.broadcast_replace_to(
        FxRateUpload.status_stream_for(account_id: upload.created_by_id),
        target: FxRateUpload.status_dom_id,
        partial: "admin/fx/history/upload_status",
        locals: {upload: upload}
      )
    end
  end

  def broadcast_table(upload)
    upload = FxRateUpload.find_by(id: upload.id)
    return if upload.blank?

    I18n.with_locale(locale_for(upload)) do
      snapshot = FxDailyRate.uncached { Admin::Fx::HistorySnapshot.call(sort_order: "desc") }
      Turbo::StreamsChannel.broadcast_replace_to(
        FxRateUpload.status_stream_for(account_id: upload.created_by_id),
        target: FxRateUpload.table_dom_id,
        partial: "admin/fx/history/history_table",
        locals: {
          dates: snapshot.fetch(:dates),
          supported_pairs: snapshot.fetch(:supported_pairs),
          rates_by_pair: snapshot.fetch(:rates_by_pair),
          role: upload.created_by_role,
          sort_order: snapshot.fetch(:sort_order),
          navigation_context: {},
          empty_history: snapshot.fetch(:empty_history)
        }
      )
    end
  end

  def locale_for(upload)
    upload.created_context&.dig("locale") || upload.created_context&.dig(:locale) || I18n.default_locale
  end
end
