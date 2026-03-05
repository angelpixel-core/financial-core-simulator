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

    render json: {
      runKpis: {
        totalRuns7d: metrics[:total_runs_7d],
        totalRuns30d: metrics[:total_runs_30d],
        successRateLast50: metrics[:success_rate_last_50],
        avgDurationMsLast50: metrics[:avg_duration_ms_last_50]
      },
      runsTrend14d: metrics[:runs_trend_14d],
      statusMix30d: metrics[:status_mix_30d],
      latestRun: metrics[:latest_run],
      globalSummary: metrics[:latest_global],
      topAccounts: metrics[:top_accounts]
    }, status: :ok
  end

  def dashboard_top_accounts
    metrics = dashboard_metrics
    render json: { topAccounts: metrics[:top_accounts] || [] }, status: :ok
  end

  def dashboard_risk
    metrics = dashboard_metrics
    render json: { riskView: metrics[:risk_view] || {} }, status: :ok
  end

  def dashboard_trend
    metrics = dashboard_metrics
    render json: { runsTrend14d: metrics[:runs_trend_14d] || [] }, status: :ok
  end

  def dashboard_latest_run
    metrics = dashboard_metrics
    render json: { latestRun: metrics[:latest_run] }, status: :ok
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
    Admin::DashboardMetrics.new.call
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
