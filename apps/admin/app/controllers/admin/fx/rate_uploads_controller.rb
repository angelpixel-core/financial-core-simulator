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

    upload = Admin::Fx::Api.start_rate_upload(
      file: file,
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: request_context
    )

    session[:fx_rate_upload_id] = upload.id
    session[:fx_rate_upload_active] = true

    broadcast_status(upload)

    Admin::Fx::Api.enqueue_rate_upload(upload.id)

    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
      notice: t("admin.fx.history.upload.processing")
  rescue => e
    Rails.logger.error(
      "[fx-rate-upload] create failed #{e.class}: #{e.message}\n#{Array(e.backtrace).first(8).join("\n")}"
    )

    if upload
      upload.update!(status: "error", error_message: e.message)
      Admin::Fx::Api.mark_upload_exception(upload: upload, message: e.message)
      broadcast_status(upload)
    end
    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
      alert: t("admin.fx.history.upload.error", message: e.message)
  end

  def preview
    file = params[:file]
    if file.blank?
      render_preview(state: :error, errors: [{code: "MISSING_FILE"}], status: :unprocessable_content)
      return
    end

    result = Admin::Fx::Api.preview_rate_upload(file_path: file.path)
    render_preview(
      state: result.valid? ? :success : :invalid,
      summary: {
        rows_count: result.total_rows,
        sample_rows_count: result.sample_rows.size
      },
      sample_rows: result.sample_rows,
      errors: result.errors,
      file_name: file.original_filename,
      sample_rows_truncated: result.total_rows > result.sample_rows.size
    )
  rescue => e
    render_preview(
      state: :error,
      errors: [{code: "PREVIEW_FAILED", message: e.message}],
      status: :unprocessable_content,
      file_name: file&.respond_to?(:original_filename) ? file.original_filename : nil
    )
  end

  def clear
    deleted_count = Admin::Fx::Api.clear_daily_rates
    session.delete(:fx_rate_upload_id)
    session.delete(:fx_rate_upload_active)
    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale),
      notice: t("admin.fx.history.upload.clear_success", count: deleted_count)
  end

  def template
    template = Admin::Fx::Api.generate_rate_upload_template
    send_data template.data,
      filename: template.filename,
      type: template.content_type,
      disposition: "attachment"
  end

  private

  def render_preview(state:, summary: nil, sample_rows: [], errors: [], status: :ok, file_name: nil,
    sample_rows_truncated: false)
    @state = state
    @summary = summary
    @sample_rows = sample_rows
    @errors = errors
    @file_name = file_name
    @sample_rows_truncated = sample_rows_truncated

    render "admin/fx/rate_uploads/preview", status: status
  end

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
