# frozen_string_literal: true

class Admin::Fx::RateUploadsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!
  skip_before_action :authorize_admin_session_operator!, only: :template
  before_action :authorize_fx_upload_policy!

  def create
    upload = nil
    file = params[:file]
    if file.blank?
      redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
        alert: t("admin.fx.history.upload.missing")
      return
    end

    upload = FxRateUpload.create!(
      status: "processing",
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: request_context,
      original_filename: file.original_filename
    )
    session[:fx_rate_upload_id] = upload.id
    session[:fx_rate_upload_active] = true

    upload.update!(file_path: persist_file(file, upload.id))
    broadcast_status(upload)

    Admin::Fx::RateUploadJob.perform_later(upload.id)

    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
      notice: t("admin.fx.history.upload.processing")
  rescue => e
    if upload
      upload.update!(status: "error", error_message: e.message)
      broadcast_status(upload)
    end
    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
      alert: t("admin.fx.history.upload.error", message: e.message)
  end

  def template
    template = Admin::Fx::RateUploadTemplate.generate
    send_data template.data,
      filename: template.filename,
      type: template.content_type,
      disposition: "attachment"
  end

  private

  def authorize_fx_upload_policy!
    query = (action_name == "template") ? :template? : :upload?
    authorize_policy!(FxRatePolicy, query, record: :fx_rate)
  end

  def request_context
    {
      source: "fx_history_upload",
      ip: request.remote_ip,
      locale: I18n.locale
    }
  end

  def persist_file(file, upload_id)
    directory = Rails.root.join("tmp", "fx_rate_uploads")
    FileUtils.mkdir_p(directory)
    file_path = directory.join("#{upload_id}-#{SecureRandom.hex(6)}.xlsx")
    File.binwrite(file_path, file.read)
    file_path.to_s
  end

  def broadcast_status(upload)
    Turbo::StreamsChannel.broadcast_replace_to(
      FxRateUpload.status_stream_for(account_id: upload.created_by_id),
      target: FxRateUpload.status_dom_id,
      partial: "admin/fx/history/upload_status",
      locals: {upload: upload}
    )
  end
end
