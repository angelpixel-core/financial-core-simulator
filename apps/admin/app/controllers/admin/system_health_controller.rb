class Admin::SystemHealthController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :authorize_system_health_policy!
  before_action :load_navigation_context

  def show
    @metrics = Admin::Dashboard::Api.read_metrics
    @pnl_trend_pagination = pnl_trend_pagination(metrics: @metrics, page: params[:pnl_page])
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    ingestion_errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    @ingestion_errors_pagination = ingestion_errors_pagination(errors: ingestion_errors, page: params[:errors_page])
    @ingestion_validation_errors = @ingestion_errors_pagination[:entries]
    @fx_ingestion_failures = fx_ingestion_failures
    @fx_observability_sources = FxRateSource.order(:name)
    @fx_observability_source = resolve_fx_source(params[:fx_source_id])
    @fx_observability_days = normalize_fx_days(params[:fx_days])
    @fx_observability_snapshot = Admin::Fx::ObservabilitySnapshot.call(
      source_id: @fx_observability_source&.id,
      days: @fx_observability_days
    )
    @fx_observability_recent_failure = recent_fx_failure(@fx_observability_snapshot)
  end

  def pnl_trend
    @metrics = Admin::Dashboard::Api.read_metrics
    @pnl_trend_pagination = pnl_trend_pagination(metrics: @metrics, page: params[:page])
    render partial: "admin/system_health/pnl_trend_frame", locals: {pagination: @pnl_trend_pagination}
  end

  private

  def authorize_system_health_policy!
    authorize_policy!(SystemHealthPolicy, :"#{action_name}?", record: :system_health)
  end

  def load_navigation_context
    @navigation_context = Runs::Api.navigation_context(params: params, session: session)
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
      Admin::Dashboard::Api.seed_ingestion_validation_errors(source: source, field: field)
    else
      Admin::Dashboard::Api.dashboard_metrics_ingestion_errors(source: source, field: field)
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

  def fx_ingestion_failures
    FxRateIngestion.includes(:source)
      .where(status: "failed")
      .order(created_at: :desc)
      .limit(10)
      .map { |ingestion| map_fx_ingestion_failure(ingestion) }
  end

  def map_fx_ingestion_failure(ingestion)
    context = ingestion.context.is_a?(Hash) ? ingestion.context : {}
    details = Admin::Fx::Ingestion::ErrorCatalog.details_for(ingestion.error_code)
    user_message_key = context["user_message_key"] || details[:user_message_key]
    action_hint_key = context["action_hint_key"] || details[:action_hint_key]

    {
      source: ingestion.source&.name || ingestion.source_id,
      error_code: ingestion.error_code,
      severity: context["severity"] || details[:severity],
      user_message: translate_catalog_key(user_message_key),
      action_hint: translate_catalog_key(action_hint_key),
      occurred_at: ingestion.updated_at&.utc&.iso8601
    }
  end

  def translate_catalog_key(key)
    return nil if key.blank?

    I18n.t(key, default: key.to_s)
  end

  def resolve_fx_source(source_id)
    return nil if source_id.blank?

    FxRateSource.find_by(id: source_id)
  end

  def normalize_fx_days(value)
    number = value.to_i
    return number if number.positive?

    Admin::Fx::ObservabilitySnapshot::DEFAULT_DAYS
  end

  def recent_fx_failure(snapshot)
    events = Array(snapshot[:events])
    failure = events.find { |event| event[:error_code].present? }
    return nil if failure.nil?

    {
      error_code: failure[:error_code],
      occurred_at: failure[:created_at]
    }
  end

  def dashboard_read_path_config
    @dashboard_read_path_config ||= Admin::Dashboard::Api.read_path_config
  end

  def normalize_filter_value(value)
    normalized = value.to_s.strip
    return nil if normalized.empty?

    normalized
  end
end
