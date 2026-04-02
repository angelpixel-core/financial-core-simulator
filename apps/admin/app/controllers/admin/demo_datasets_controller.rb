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

    timeline_enabled = timeline_enabled?
    result = Admin::DemoDataset::ExcelToInputParser.call(
      file_path: file.path,
      timeline_enabled: timeline_enabled
    )

    if result.valid?
      run = Run.create!(input_json: result.input)
      fee_enabled = result.input.dig("feeModel", "enabled")
      with_timeline_env(timeline_enabled) do
        Runs::Execute.new.call(run, fee_enabled: fee_enabled)
        Runs::VerifyInputHash.new.call(run)
      end
      upload = DemoDatasetUpload.create!(status: :valid, run_id: run.id)
      Admin::Fx::UploadRateGapProcessor.call(
        input: result.input,
        run: run,
        upload: upload,
        reporting_currency: ReportingSetting.current.reporting_currency
      )
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        notice: t("admin.overview.dataset.flash.valid")
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
      timeline_enabled: timeline_enabled?
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

  def timeline_enabled?
    return true unless params.key?(:timeline_enabled)

    ActiveModel::Type::Boolean.new.cast(params[:timeline_enabled])
  end

  def with_timeline_env(enabled)
    previous = ENV.fetch("FCS_TIMELINE_ENABLED", nil)
    ENV["FCS_TIMELINE_ENABLED"] = enabled ? "1" : "0"
    yield
  ensure
    if previous.nil?
      ENV.delete("FCS_TIMELINE_ENABLED")
    else
      ENV["FCS_TIMELINE_ENABLED"] = previous
    end
  end
end
