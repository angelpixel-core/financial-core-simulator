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
      respond_upload_create_error(
        message: t("admin.fx.history.upload.missing"),
        code: "MISSING_FILE"
      )
      return
    end

    if upload_file_too_large?(file, stage: :process)
      respond_upload_create_error(
        message: t("admin.fx.history.upload.file_too_large", max_mb: Admin::UploadLimits.max_upload_file_size_mb),
        code: "FILE_SIZE_EXCEEDED"
      )
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

    respond_upload_create_success(
      message: t("admin.fx.history.upload.processing"),
      upload: upload
    )
  rescue => e
    Admin::UploadTelemetry.rejection(
      domain: "fx",
      stage: "process",
      reason: "parse_error",
      message: e.message,
      original_filename: file&.respond_to?(:original_filename) ? file.original_filename : nil
    )
    Rails.logger.error(
      "[fx-rate-upload] create failed #{e.class}: #{e.message}\n#{Array(e.backtrace).first(8).join("\n")}"
    )

    if upload
      upload.update!(status: "error", error_message: e.message)
      Admin::Fx::Api.mark_upload_exception(upload: upload, message: e.message)
      broadcast_status(upload)
    end
    respond_upload_create_error(
      message: t("admin.fx.history.upload.error", message: e.message),
      code: "UPLOAD_FAILED",
      upload: upload
    )
  end

  def preview
    file = params[:file]
    if file.blank?
      render_preview(state: :error, errors: [{code: "MISSING_FILE"}], status: :unprocessable_content)
      return
    end

    if upload_file_too_large?(file, stage: :preview)
      render_preview(
        state: :invalid,
        errors: [
          {
            code: "FILE_SIZE_EXCEEDED",
            message: t("admin.fx.history.upload.file_too_large", max_mb: Admin::UploadLimits.max_upload_file_size_mb)
          }
        ],
        status: :unprocessable_content,
        file_name: file.original_filename
      )
      return
    end

    result = Admin::Fx::Api.preview_rate_upload(file_path: file.path)
    preview_errors = Array(result.errors)
    errors_truncated = result.respond_to?(:total_errors) ? result.total_errors > preview_errors.size : false

    render_preview(
      state: result.valid? ? :success : :invalid,
      summary: {
        rows_count: result.total_rows,
        sample_rows_count: result.sample_rows.size
      },
      sample_rows: result.sample_rows,
      errors: preview_errors,
      file_name: file.original_filename,
      sample_rows_truncated: result.total_rows > result.sample_rows.size,
      errors_truncated: errors_truncated
    )
  rescue => e
    Admin::UploadTelemetry.rejection(
      domain: "fx",
      stage: "preview",
      reason: "parse_error",
      message: e.message,
      original_filename: file&.respond_to?(:original_filename) ? file.original_filename : nil
    )
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
    sample_rows_truncated: false, errors_truncated: false)
    if request.format.json?
      render json: {
        state: state,
        summary: summary,
        sample_rows: sample_rows,
        errors: errors,
        file_name: file_name,
        sample_rows_truncated: sample_rows_truncated,
        errors_truncated: errors_truncated
      }, status: status
      return
    end

    @state = state
    @summary = summary
    @sample_rows = sample_rows
    @errors = errors
    @file_name = file_name
    @sample_rows_truncated = sample_rows_truncated
    @errors_truncated = errors_truncated

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

  def upload_file_too_large?(file, stage:)
    return false unless Admin::UploadLimits.exceeds_file_size?(file: file)

    Admin::UploadTelemetry.rejection(
      domain: "fx",
      stage: stage,
      reason: "file_size_exceeded",
      max_file_size_bytes: Admin::UploadLimits.max_upload_file_size_bytes,
      file_size_bytes: Admin::UploadLimits.file_size_bytes(file: file),
      original_filename: file.original_filename
    )
    true
  end

  def respond_upload_create_error(message:, code:, upload: nil)
    if request.format.json?
      render json: {
        state: "invalid",
        code: code,
        message: message,
        upload_id: upload&.id
      }, status: :unprocessable_content
      return
    end

    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale), alert: message
  end

  def respond_upload_create_success(message:, upload:)
    if request.format.json?
      render json: {
        state: "processing",
        message: message,
        upload_id: upload.id
      }, status: :accepted
      return
    end

    redirect_back fallback_location: admin_fx_history_index_path(locale: I18n.locale), notice: message
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
      Admin::Fx::Api.history_stream(account_id: upload.created_by_id),
      target: FxRateUpload.status_dom_id,
      partial: "admin/fx/history/upload_status",
      locals: {upload: upload}
    )
  end
end
