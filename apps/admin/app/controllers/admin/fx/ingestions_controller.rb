# frozen_string_literal: true

class Admin::Fx::IngestionsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!
  before_action :authorize_fx_ingestion_policy!
  before_action :load_navigation_context

  def sync
    if params[:source_id].blank?
      return render json: {error: "missing_source_id"}, status: :unprocessable_content if request.format.json?

      return redirect_to admin_fx_history_index_path(@navigation_context),
        alert: t("admin.fx.history.sync.select_source_hint")
    end

    source = fx_sources.find { |item| item.id == params[:source_id].to_i }
    if source.nil?
      return render json: {error: "invalid_source_id"}, status: :unprocessable_content if request.format.json?

      return redirect_to admin_fx_history_index_path(@navigation_context),
        alert: t("admin.fx.history.sync.select_source_hint")
    end

    market = params[:market].to_s.upcase
    unless available_markets_for(source).include?(market)
      return render json: {error: "invalid_market"}, status: :unprocessable_content if request.format.json?

      return redirect_to admin_fx_history_index_path(@navigation_context.merge(source_id: source.id)),
        alert: t("admin.fx.history.sync.select_market_hint")
    end

    correlation_id = SecureRandom.uuid
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "pending",
      correlation_id: correlation_id,
      metadata: {
        "market" => market,
        "requested_by_account_id" => current_admin_account&.id,
        "requested_by_role" => admin_shell_role,
        "requested_locale" => I18n.locale.to_s
      }
    )

    Admin::Fx::FetchFxRatesJob.perform_later(
      source.id,
      correlation_id: correlation_id,
      ingestion_id: ingestion.id,
      market: market
    )

    respond_to do |format|
      format.turbo_stream do
        redirect_to admin_fx_history_index_path(@navigation_context.merge(sync_source_id: source.id, market: market))
      end
      format.json do
        render json: {
          status: "queued",
          ingestion_id: ingestion.id,
          source_id: source.id,
          market: market
        }, status: :ok
      end
      format.html do
        redirect_to admin_fx_history_index_path(@navigation_context.merge(sync_source_id: source.id, market: market)),
          notice: t("admin.fx.history.sync.started")
      end
    end
  rescue => e
    raise unless request.format.json?

    render json: {error: "internal_error", message: e.message}, status: :internal_server_error
  end

  def index
    if params[:source_id].present?
      source = FxRateSource.find_by(id: params[:source_id])
      return render json: {error: "invalid_source_id"}, status: :unprocessable_content if source.nil?
    end

    sources = fx_sources
    sources = sources.where(id: params[:source_id]) if params[:source_id].present?
    latest = latest_ingestions(sources)

    render json: {
      sources: sources.map do |source|
        ingestion = latest[source.id]
        {
          source_id: source.id,
          source_name: source.name,
          ingestion_id: ingestion&.id,
          status: ingestion&.status,
          error_code: ingestion&.error_code,
          created_at: ingestion&.created_at&.iso8601,
          updated_at: ingestion&.updated_at&.iso8601
        }
      end
    }, status: :ok
  rescue => e
    raise unless request.format.json?

    render json: {error: "internal_error", message: e.message}, status: :internal_server_error
  end

  private

  def authorize_fx_ingestion_policy!
    authorize_policy!(FxRatePolicy, :ingest?, record: :fx_rate)
  end

  def latest_ingestions(sources)
    FxRateIngestion.where(source_id: sources.map(&:id))
      .order(created_at: :desc)
      .group_by(&:source_id)
      .transform_values(&:first)
  end

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end

  def available_markets_for(source)
    Admin::Fx::Api.available_markets_for(source: source)
  end

  def fx_sources
    @fx_sources ||= Admin::Fx::Api.active_sources.to_a
  end
end
