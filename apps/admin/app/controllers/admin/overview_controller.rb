class Admin::OverviewController < ApplicationController
  before_action :authorize_admin_ui!

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
    render json: { errors: dashboard_ingestion_validation_errors(source: source, field: field) }, status: :ok
  end

  def dashboard_overview
    metrics = dashboard_metrics
    render json: overview_response_serializer.serialize(metrics: metrics), status: :ok
  end

  def dashboard_top_accounts
    metrics = dashboard_metrics
    render json: widget_response_serializer.top_accounts(metrics: metrics), status: :ok
  end

  def dashboard_risk
    metrics = dashboard_metrics
    render json: widget_response_serializer.risk(metrics: metrics), status: :ok
  end

  def dashboard_trend
    metrics = dashboard_metrics
    render json: widget_response_serializer.trend(metrics: metrics), status: :ok
  end

  def dashboard_latest_run
    metrics = dashboard_metrics
    render json: widget_response_serializer.latest_run(metrics: metrics), status: :ok
  end

  def ingestion_validation_errors_panel
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    @errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    if request.xhr?
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

  def authorize_admin_ui!
    auth = Admin::Authorization.new(request: request)
    return if auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")

    render plain: "Forbidden", status: :forbidden
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

  def dashboard_ingestion_validation_errors(source: nil, field: nil)
    Admin::DashboardMetrics.new.ingestion_validation_errors(source: source, field: field)
  end

  def normalize_filter_value(value)
    normalized = value.to_s.strip
    return nil if normalized.empty?

    normalized
  end
end
