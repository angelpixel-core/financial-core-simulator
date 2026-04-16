# frozen_string_literal: true

class Admin::Fx::RateUploadJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    upload = Admin::Fx::ProcessRateUpload.new.call(upload_id: upload_id)
  rescue StandardError
    upload = Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new.find_by_id(upload_id)
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
    upload = Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new.find_by_id(upload.id)
    return if upload.blank?

    I18n.with_locale(locale_for(upload)) do
      Turbo::StreamsChannel.broadcast_replace_to(
        FxRateUpload.status_stream_for(account_id: upload.created_by_id),
        target: FxRateUpload.status_dom_id,
        partial: 'admin/fx/history/upload_status',
        locals: { upload: upload }
      )
    end
  end

  def broadcast_table(upload)
    upload = Admin::Fx::Repositories::ActiveRecord::RateUploadRepository.new.find_by_id(upload.id)
    return if upload.blank?

    I18n.with_locale(locale_for(upload)) do
      snapshot = Admin::Fx::Rates::Repository.new.uncached_history_snapshot(sort_order: 'desc')
      Turbo::StreamsChannel.broadcast_replace_to(
        FxRateUpload.status_stream_for(account_id: upload.created_by_id),
        target: FxRateUpload.table_dom_id,
        partial: 'admin/fx/history/history_table',
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
    upload.created_context&.dig('locale') || upload.created_context&.dig(:locale) || I18n.default_locale
  end
end
