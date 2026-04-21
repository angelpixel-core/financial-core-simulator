# frozen_string_literal: true

class Admin::DemoDatasetsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_demo_dataset_policy!

  def create
    file = params[:file]
    if file.blank?
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.overview.dataset.flash.missing_file")
      return
    end

    outcome = Admin::DemoDataset::Api.process_upload(
      file_path: file.path,
      timeline_enabled: timeline_enabled?
    )

    if outcome[:valid]
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        notice: t("admin.overview.dataset.flash.valid")
    else
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.overview.dataset.flash.invalid")
    end
  end

  def reset
    Admin::DemoDataset::Api.reset_data
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.overview.dataset.flash.reset")
  end

  def preview
    file = params[:file]
    if file.blank?
      render_preview(state: :error, errors: [{code: "MISSING_FILE"}], status: :unprocessable_content)
      return
    end

    preview = Admin::DemoDataset::Api.preview_upload(
      file_path: file.path,
      timeline_enabled: timeline_enabled?
    )

    render_preview(
      state: preview.fetch(:state),
      summary: preview.fetch(:summary),
      sample_rows: preview.fetch(:sample_rows),
      errors: preview.fetch(:errors),
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

  def timeline_enabled?
    return true unless params.key?(:timeline_enabled)

    ActiveModel::Type::Boolean.new.cast(params[:timeline_enabled])
  end

  def authorize_demo_dataset_policy!
    authorize_with_policy!(
      policy_class: Admin::Demo::DatasetPolicy,
      query: :"#{action_name}?",
      record: :demo_dataset,
      required_role: "operator",
      gate: :session
    )
  end
end
