class Admin::OverviewController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_overview_session_viewer!, only: %i[
    show
    runs_trend
    status_mix
    top_accounts
    export_financial_overview
    ingestion_validation_errors_panel
  ]
  before_action :authorize_overview_policy!, only: %i[
    show
    runs_trend
    status_mix
    top_accounts
    export_financial_overview
    ingestion_validation_errors_panel
  ]
  before_action :authorize_dashboard_viewer!, only: %i[
    dashboard_overview
    dashboard_financial_overview
    dashboard_top_accounts
    dashboard_risk
    dashboard_trend
    dashboard_latest_run
    ingestion_validation_errors
  ]
  before_action :load_navigation_context, only: %i[show top_accounts ingestion_validation_errors_panel]
  rescue_from Admin::Dashboard::Api.read_path_unavailable_error, with: :render_dashboard_unavailable

  def show
    @selected_trades_window = normalized_trades_window_param(params[:trades_window])
    @selected_trades_window_label = trades_window_label(@selected_trades_window)
    @metrics = dashboard_metrics
    @top_accounts_pagination = top_accounts_pagination(metrics: @metrics, page: params[:top_accounts_page])
    @selected_source = normalize_filter_value(params[:source])
    @selected_field = normalize_filter_value(params[:field])
    ingestion_errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    @ingestion_errors_pagination = ingestion_errors_pagination(errors: ingestion_errors, page: params[:errors_page])
    @ingestion_validation_errors = @ingestion_errors_pagination[:entries]
    @overview_recent_events = dashboard_ingestion_validation_errors.first(15)
    @reliable_selection = Runs::Api.reliable_selection
    @demo_sandbox_state = DemoSandboxState.current
    @demo_lock_info = load_demo_lock_info
    @demo_usage_summary = Admin::Demo::AbuseProtection.summary
    load_fx_context
  end

  def top_accounts
    unless turbo_frame_request? || request.xhr?
      redirect_to admin_overview_path(locale: I18n.locale)
      return
    end

    @metrics = dashboard_metrics
    @top_accounts_pagination = top_accounts_pagination(metrics: @metrics, page: params[:page])
    render partial: "admin/overview/top_accounts_frame",
      locals: {metrics: @metrics, pagination: @top_accounts_pagination, show_drilldown: false,
               navigation_context: @navigation_context}
  end

  def runs_trend
    @metrics = dashboard_metrics
  end

  def status_mix
    @metrics = dashboard_metrics
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

  def dashboard_financial_overview
    run = Admin::Dashboard::Api.find_run_by_id(params[:run_id])
    return render json: {"error" => "run_not_found"}, status: :not_found if run.nil?

    account_id = normalize_filter_value(params[:account_id])
    market_id = normalize_filter_value(params[:market_id])
    run_filenames = normalized_filter_values(params[:run_filenames])
    metrics = financial_overview_metrics(
      run: run,
      account_id: account_id,
      market_id: market_id,
      run_filenames: run_filenames
    ).call
    render json: financial_overview_response_serializer.serialize(metrics: metrics), status: :ok
  rescue
    fallback_metrics = {trade_activity: [], trade_volume: [], pnl_daily: []}
    render json: financial_overview_response_serializer.serialize(metrics: fallback_metrics), status: :ok
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
    errors = dashboard_ingestion_validation_errors(source: @selected_source, field: @selected_field)
    @errors_pagination = ingestion_errors_pagination(errors: errors, page: params[:errors_page])
    @errors = @errors_pagination[:entries]
    if turbo_frame_request?
      render partial: "admin/overview/ingestion_validation_errors_frame", locals: {
        errors: @errors,
        pagination: @errors_pagination,
        selected_source: @selected_source,
        selected_field: @selected_field,
        show_drilldown: true,
        navigation_context: @navigation_context
      }
    elsif request.xhr?
      render partial: "admin/overview/ingestion_validation_errors", locals: {
        errors: @errors,
        pagination: @errors_pagination,
        selected_source: @selected_source,
        selected_field: @selected_field,
        show_drilldown: true,
        navigation_context: @navigation_context
      }
    else
      render :ingestion_validation_errors
    end
  end

  def export_financial_overview
    run = Admin::Dashboard::Api.find_run_by_id(params[:run_id])
    return render plain: "run_not_found", status: :not_found if run.nil?

    exporter = Admin::Dashboard::FinancialOverviewExporter.new(
      run: run,
      card_type: params[:card_type],
      account_id: normalize_filter_value(params[:account_id]),
      market_id: normalize_filter_value(params[:market_id]),
      run_filenames: normalized_filter_values(params[:run_filenames])
    )

    respond_to do |format|
      format.json do
        send_data(
          JSON.pretty_generate(exporter.export_json),
          filename: exporter.filename_for(:json),
          type: "application/json",
          disposition: "attachment"
        )
      end
      format.pdf do
        send_data(
          exporter.export_pdf,
          filename: exporter.filename_for(:pdf),
          type: "application/pdf",
          disposition: "attachment"
        )
      end
    end
  rescue Admin::Dashboard::FinancialOverviewExporter::UnsupportedCardTypeError
    render plain: "unsupported_card_type", status: :unprocessable_content
  end

  private

  def authorize_overview_session_viewer!
    authorize_admin_session_viewer!
  end

  def authorize_dashboard_viewer!
    authorize_machine_or_session_viewer!
  end

  def authorize_overview_policy!
    authorize_policy!(OverviewPolicy, :"#{action_name}?", record: :overview)
  end

  def dashboard_metrics
    Admin::Dashboard::Api.read_metrics(trades_window: normalized_trades_window_param(params[:trades_window]))
  end

  def dashboard_compatibility_guard
    @dashboard_compatibility_guard ||= Admin::Dashboard::Api.compatibility_guard
  end

  def overview_response_serializer
    @overview_response_serializer ||= Admin::Dashboard::Api.overview_response_serializer(
      compatibility_guard: dashboard_compatibility_guard
    )
  end

  def widget_response_serializer
    @widget_response_serializer ||= Admin::Dashboard::Api.widget_response_serializer(
      compatibility_guard: dashboard_compatibility_guard
    )
  end

  def financial_overview_response_serializer
    @financial_overview_response_serializer ||= Admin::Dashboard::Api.financial_overview_response_serializer
  end

  def ingestion_validation_errors_response_serializer
    @ingestion_validation_errors_response_serializer ||= Admin::Dashboard::Api.ingestion_validation_errors_response_serializer
  end

  def financial_overview_metrics(run:, account_id: nil, market_id: nil, run_filenames: [])
    Admin::Dashboard::Api.financial_overview_metrics(
      run: run,
      account_id: account_id,
      market_id: market_id,
      run_filenames: run_filenames
    )
  end

  def dashboard_ingestion_validation_errors(source: nil, field: nil)
    if dashboard_read_path_config.seed_enabled?
      Admin::Dashboard::Api.seed_ingestion_validation_errors(source: source, field: field)
    else
      Admin::Dashboard::Api.dashboard_metrics_ingestion_errors(source: source, field: field)
    end
  end

  def render_dashboard_json
    metrics = dashboard_metrics
    render json: yield(metrics), status: :ok
  end

  def render_dashboard_unavailable(_error)
    render json: {
      "contractVersion" => Admin::Dashboard::Api.compatibility_contract_version,
      "error" => "dashboard_read_unavailable"
    }, status: :service_unavailable
  end

  def normalize_filter_value(value)
    normalized = value.to_s.strip
    return nil if normalized.empty?

    normalized
  end

  def normalized_filter_values(values)
    Array(values).filter_map do |value|
      normalized = value.to_s.strip
      normalized.presence
    end.uniq
  end

  def normalized_trades_window_param(value)
    normalized = value.to_s.strip.downcase
    return normalized if %w[30d 60d 90d all-time].include?(normalized)

    "all-time"
  end

  def trades_window_label(window)
    case window
    when "30d" then I18n.t("admin.overview.system_metrics.trades_window.days_30")
    when "60d" then I18n.t("admin.overview.system_metrics.trades_window.days_60")
    when "90d" then I18n.t("admin.overview.system_metrics.trades_window.days_90")
    else I18n.t("admin.overview.system_metrics.trades_window.all_time")
    end
  end

  def top_accounts_pagination(metrics:, page: nil)
    accounts = Array(metrics[:top_accounts]).sort_by { |account| -account[:total_pnl_quote].to_f }
    per_page = 5
    current = page.to_i
    current = 1 if current < 1
    total_pages = (accounts.length.to_f / per_page).ceil
    total_pages = 1 if total_pages.zero?
    current = total_pages if current > total_pages

    start_index = (current - 1) * per_page
    entries = accounts.slice(start_index, per_page) || []

    {
      entries: entries,
      page: current,
      total_pages: total_pages,
      per_page: per_page
    }
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
    @dashboard_read_path_config ||= Admin::Dashboard::Api.read_path_config
  end

  def load_fx_context
    context = Admin::Dashboard::Api.build_fx_context
    @reporting_setting = context.fetch(:reporting_setting)
    @fx_operational_date = context.fetch(:operational_date)
    @fx_base_currency = context.fetch(:base_currency)
    @fx_quote_currency = context.fetch(:quote_currency)
    @fx_rate_state = context.fetch(:rate_state)
    @fx_carry_forward_available = context.fetch(:carry_forward_available)
  end

  def load_demo_lock_info
    account = current_admin_account

    if Admin::Demo::Access.enabled? && account.present?
      Admin::Demo::Access.acquire(account_id: account.id, account_email: account.email)
    end

    {
      enabled: Admin::Demo::Access.enabled?,
      state: Admin::Demo::Access.lock_state(current_account_id: account&.id),
      owner: Admin::Demo::Access.current_user
    }
  end

  def load_navigation_context
    @navigation_context = Runs::Api.navigation_context(params: params, session: session)
  end
end
