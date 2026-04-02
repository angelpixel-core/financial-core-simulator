class Admin::SystemHealthController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def show
    @metrics = Admin::Dashboard::ReadMetrics.new.call
    @pnl_trend_pagination = pnl_trend_pagination(metrics: @metrics, page: params[:pnl_page])
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    ingestion_errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    @ingestion_errors_pagination = ingestion_errors_pagination(errors: ingestion_errors, page: params[:errors_page])
    @ingestion_validation_errors = @ingestion_errors_pagination[:entries]
  end

  def pnl_trend
    @metrics = Admin::Dashboard::ReadMetrics.new.call
    @pnl_trend_pagination = pnl_trend_pagination(metrics: @metrics, page: params[:page])
    render partial: "admin/system_health/pnl_trend_frame", locals: {pagination: @pnl_trend_pagination}
  end

  private

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end

  def pnl_trend_pagination(metrics:, page: nil)
    points = Array(metrics[:pnl_trend])
    per_page = 5
    current = page.to_i
    current = 1 if current < 1
    total_pages = (points.length.to_f / per_page).ceil
    total_pages = 1 if total_pages.zero?
    current = total_pages if current > total_pages

    start_index = (current - 1) * per_page
    entries = points.slice(start_index, per_page) || []

    {
      entries: entries,
      page: current,
      total_pages: total_pages,
      per_page: per_page
    }
  end

  def dashboard_ingestion_validation_errors(source: nil, field: nil)
    if dashboard_read_path_config.seed_enabled?
      Admin::Dashboard::SeedMetrics.new.ingestion_validation_errors(source: source, field: field)
    else
      Admin::DashboardMetrics.new.ingestion_validation_errors(source: source, field: field)
    end
  end

  def ingestion_errors_pagination(errors:, page: nil)
    per_page = 5
    current = page.to_i
    current = 1 if current < 1
    total_pages = (errors.length.to_f / per_page).ceil
    total_pages = 1 if total_pages.zero?
    current = total_pages if current > total_pages

    start_index = (current - 1) * per_page
    entries = errors.slice(start_index, per_page) || []

    {
      entries: entries,
      page: current,
      total_pages: total_pages,
      per_page: per_page
    }
  end

  def dashboard_read_path_config
    @dashboard_read_path_config ||= Admin::Dashboard::ReadPathConfig.new
  end

  def normalize_filter_value(value)
    normalized = value.to_s.strip
    return nil if normalized.empty?

    normalized
  end
end
