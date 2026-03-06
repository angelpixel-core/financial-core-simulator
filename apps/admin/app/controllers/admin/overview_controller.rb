class Admin::OverviewController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_overview_session_viewer!, only: %i[
    show
    top_accounts
    ingestion_validation_errors_panel
  ]
  before_action :authorize_dashboard_viewer!, only: %i[
    dashboard_overview
    dashboard_top_accounts
    dashboard_risk
    dashboard_trend
    dashboard_latest_run
    ingestion_validation_errors
  ]
  rescue_from Admin::Dashboard::ReadMetrics::ReadPathUnavailableError, with: :render_dashboard_unavailable

  def show
    @metrics = dashboard_metrics
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    @ingestion_validation_errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
  end

  def top_accounts
    @metrics = dashboard_metrics
    if request.xhr?
      render partial: "admin/overview/top_accounts", locals: { metrics: @metrics }
    else
      render :top_accounts
    end
  end

  def ingestion_validation_errors
    source = normalize_filter_value(params[:source])
    field = normalize_filter_value(params[:field])
    render json: ingestion_validation_errors_response_serializer.serialize(
      errors: dashboard_ingestion_validation_errors(source: source, field: field)
    ), status: :ok
  end

  def dashboard_overview
    render_dashboard_json do |metrics|
      overview_response_serializer.serialize(metrics: metrics)
    end
  end

  def dashboard_top_accounts
    render_dashboard_json do |metrics|
      widget_response_serializer.top_accounts(metrics: metrics)
    end
  end

  def dashboard_risk
    render_dashboard_json do |metrics|
      widget_response_serializer.risk(metrics: metrics)
    end
  end

  def dashboard_trend
    render_dashboard_json do |metrics|
      widget_response_serializer.trend(metrics: metrics)
    end
  end

  def dashboard_latest_run
    render_dashboard_json do |metrics|
      widget_response_serializer.latest_run(metrics: metrics)
    end
  end

  def ingestion_validation_errors_panel
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    @errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    if turbo_frame_request?
      render partial: "admin/overview/ingestion_validation_errors_frame", locals: {
        errors: @errors,
        selected_source: @selected_source,
        selected_field: @selected_field
      }
    elsif request.xhr?
      render partial: "admin/overview/ingestion_validation_errors", locals: {
        errors: @errors,
        selected_source: @selected_source,
        selected_field: @selected_field
      }
    else
      render :ingestion_validation_errors
    end
  end

  private

  def authorize_overview_session_viewer!
    authorize_admin_session_viewer!
  end

  def authorize_dashboard_viewer!
    authorize_machine_or_session_viewer!
  end

  def dashboard_metrics
    Admin::Dashboard::ReadMetrics.new.call
  end

  def dashboard_compatibility_guard
    @dashboard_compatibility_guard ||= Admin::Dashboard::CompatibilityGuard.new
  end

  def overview_response_serializer
    @overview_response_serializer ||= Admin::Dashboard::OverviewResponseSerializer.new(
      compatibility_guard: dashboard_compatibility_guard
    )
  end

  def widget_response_serializer
    @widget_response_serializer ||= Admin::Dashboard::WidgetResponseSerializer.new(
      compatibility_guard: dashboard_compatibility_guard
    )
  end

  def ingestion_validation_errors_response_serializer
    @ingestion_validation_errors_response_serializer ||= Admin::Dashboard::IngestionValidationErrorsResponseSerializer.new
  end

  def dashboard_ingestion_validation_errors(source: nil, field: nil)
    Admin::DashboardMetrics.new.ingestion_validation_errors(source: source, field: field)
  end

  def render_dashboard_json
    metrics = dashboard_metrics
    render json: yield(metrics), status: :ok
  end

  def render_dashboard_unavailable(_error)
    render json: {
      "contractVersion" => Admin::Dashboard::CompatibilityGuard::CONTRACT_VERSION,
      "error" => "dashboard_read_unavailable"
    }, status: :service_unavailable
  end

  def normalize_filter_value(value)
    normalized = value.to_s.strip
    return nil if normalized.empty?

    normalized
  end
end
