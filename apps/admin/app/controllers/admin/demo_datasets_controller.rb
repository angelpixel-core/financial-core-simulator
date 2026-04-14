# frozen_string_literal: true

require "fileutils"

class Admin::DemoDatasetsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!

  def create
    file = params[:file]
    if file.blank?
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.overview.dataset.flash.missing_file")
      return
    end

    result = Admin::DemoDataset::ExcelToInputParser.call(
      file_path: file.path,
      timeline_enabled: true
    )
    input = result.input
    trades = input.is_a?(Hash) ? Array(fetch_input_value(input, :trades)) : []

    if trades.any?
      run = Run.create!(input_json: input)
      fee_model = fetch_input_value(input, :feeModel)
      fee_enabled = fee_model.is_a?(Hash) ? (fee_model[:enabled] || fee_model["enabled"]) : false
      with_timeline_env do
        Runs::Execute.new.call(run, fee_enabled: fee_enabled)
        Runs::VerifyInputHash.new.call(run)
      end
      parser_errors = normalize_parser_errors(result.errors)
      persist_parser_validation_errors(run, parser_errors)
      run.update!(reliable: false) if parser_errors.present?

      upload_status = parser_errors.present? ? :invalid : :valid
      upload = DemoDatasetUpload.create!(status: upload_status, run_id: run.id, validation_errors: parser_errors)
      Admin::Fx::UploadRateGapProcessor.call(
        input: input,
        run: run,
        upload: upload,
        reporting_currency: ReportingSetting.current.reporting_currency
      )
      message_key = parser_errors.present? ? "admin.overview.dataset.flash.partial" : "admin.overview.dataset.flash.valid"
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        notice: t(message_key)
    else
      DemoDatasetUpload.create!(status: :invalid, validation_errors: result.errors)
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.overview.dataset.flash.invalid")
    end
  end

  def reset
    Run.delete_all
    DemoDatasetUpload.delete_all
    FileUtils.rm_rf(Rails.root.join("storage", "runs"))
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.overview.dataset.flash.reset")
  end

  def preview
    file = params[:file]
    if file.blank?
      render_preview(state: :error, errors: [{code: "MISSING_FILE"}], status: :unprocessable_content)
      return
    end

    result = Admin::DemoDataset::ExcelToInputParser.call(
      file_path: file.path,
      timeline_enabled: true
    )
    input = result.input
    summary = build_preview_summary(input)
    sample_rows = if input.is_a?(Hash)
      Array(fetch_input_value(input, :trades))
    else
      []
    end

    render_preview(
      state: result.valid? ? :success : :invalid,
      summary: summary,
      sample_rows: sample_rows,
      errors: result.errors,
      file_name: file.original_filename
    )
  rescue => e
    render_preview(
      state: :error,
      errors: [{code: "PARSE_FAILED", message: e.message}],
      status: :unprocessable_content,
      file_name: file&.respond_to?(:original_filename) ? file.original_filename : nil
    )
  end

  private

  def render_preview(state:, summary: nil, sample_rows: [], errors: [], status: :ok, file_name: nil)
    @state = state
    @summary = summary
    @sample_rows = sample_rows
    @errors = errors
    @file_name = file_name

    render "admin/demo_datasets/preview", status: status
  end

  def build_preview_summary(input)
    return nil unless input.is_a?(Hash)

    fee_model = fetch_input_value(input, :feeModel)

    {
      trades_count: Array(fetch_input_value(input, :trades)).size,
      accounts_count: Array(fetch_input_value(input, :accounts)).size,
      markets_count: Array(fetch_input_value(input, :markets)).size,
      schema_version: fetch_input_value(input, :schemaVersion),
      fee_enabled: fee_model.is_a?(Hash) ? (fee_model[:enabled] || fee_model["enabled"]) : nil
    }
  end

  def fetch_input_value(input, key)
    return input[key] if input.key?(key)

    input[key.to_s]
  end

  def normalize_parser_errors(errors)
    Array(errors).map do |error|
      normalized = error.respond_to?(:to_h) ? error.to_h.symbolize_keys : {}
      {
        line: normalized[:line],
        code: normalized[:code],
        source: normalized[:source].presence || "dataset_upload",
        row_index: normalized[:row_index],
        trade_id: normalized[:trade_id],
        account_id: normalized[:account_id],
        market_id: normalized[:market_id]
      }
    end
  end

  def persist_parser_validation_errors(run, errors)
    return if errors.blank?

    correlation_id = run.run_uuid.presence || "run-#{run.id}"
    now = Time.current
    entries = errors.map do |error|
      {
        run_id: run.id,
        source: error[:source],
        field: "trades",
        message: error[:code].to_s,
        code: error[:code],
        trade_id: error[:trade_id],
        account_id: error[:account_id],
        market_id: error[:market_id],
        row_index: error[:row_index],
        correlation_id: correlation_id,
        created_at: now,
        updated_at: now
      }
    end

    RunValidationError.insert_all(entries)
  end

  def with_timeline_env
    previous = ENV.fetch("FCS_TIMELINE_ENABLED", nil)
    ENV["FCS_TIMELINE_ENABLED"] = "1"
    yield
  ensure
    if previous.nil?
      ENV.delete("FCS_TIMELINE_ENABLED")
    else
      ENV["FCS_TIMELINE_ENABLED"] = previous
    end
  end
end
