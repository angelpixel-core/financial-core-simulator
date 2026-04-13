# frozen_string_literal: true

class Admin::Fx::HistoryController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def index
    @selected_source = resolve_source(params[:source_id])
    snapshot = Admin::Fx::HistorySnapshot.call(sort_order: params[:sort], source_id: @selected_source&.id)
    @supported_pairs = snapshot.fetch(:supported_pairs)
    @sort_order = snapshot.fetch(:sort_order)
    @rates_by_pair = snapshot.fetch(:rates_by_pair)
    @dates = snapshot.fetch(:dates)
    @empty_history = snapshot.fetch(:empty_history)
    @rate_lineage = build_rate_lineage(snapshot.fetch(:rates))
    @fx_sources = FxRateSource.order(:name)
    @latest_ingestions = latest_ingestions(@fx_sources, selected_source: @selected_source)
    @recent_events = recent_events(selected_source: @selected_source)
    session_upload_id = session[:fx_rate_upload_id]
    upload_active = session[:fx_rate_upload_active] == true
    @latest_upload = if upload_active && session_upload_id.present?
      FxRateUpload.visible_for_upload(
        upload_id: session_upload_id,
        account_id: current_admin_account&.id
      )
    end
    if @latest_upload.blank?
      session.delete(:fx_rate_upload_id)
      session.delete(:fx_rate_upload_active)
    elsif @latest_upload.processed_at.present?
      session.delete(:fx_rate_upload_id)
      session.delete(:fx_rate_upload_active)
    end
    @upload_status_stream = if admin_shell_operator? || admin_shell_admin?
      FxRateUpload.status_stream_for(account_id: current_admin_account&.id)
    end
  end

  private

  def latest_ingestions(sources, selected_source: nil)
    scope = FxRateIngestion.where(source_id: sources.map(&:id))
    scope = scope.where(source_id: selected_source.id) if selected_source.present?
    scope
      .order(created_at: :desc)
      .group_by(&:source_id)
      .transform_values(&:first)
  end

  def recent_events(selected_source: nil)
    scope = FxRateEvent.order(created_at: :desc)
    if selected_source.present?
      source_id = selected_source.id.to_s
      scope = scope.where("data ->> 'source_id' = ? OR metadata ->> 'source_id' = ?", source_id, source_id)
    end
    scope.limit(10)
  end

  def resolve_source(source_id)
    return nil if source_id.blank?

    FxRateSource.find_by(id: source_id)
  end

  def build_rate_lineage(rates)
    rates = rates.compact
    ingestion_ids = rates.map do |rate|
      rate.created_context&.dig("ingestion_id") || rate.created_context&.dig(:ingestion_id)
    end
      .compact
    upload_ids = rates.map(&:source_upload_id).compact
    ingestions = FxRateIngestion.where(id: ingestion_ids).index_by(&:id)
    uploads = FxRateUpload.where(id: upload_ids).index_by(&:id)
    events_by_ingestion = fx_events_by_ingestion(ingestion_ids)

    rates.each_with_object({}) do |rate, acc|
      ingestion_id = rate.created_context&.dig("ingestion_id") || rate.created_context&.dig(:ingestion_id)
      ingestion = ingestion_id.present? ? ingestions[ingestion_id.to_i] : nil
      upload = rate.source_upload_id.present? ? uploads[rate.source_upload_id] : nil
      events = ingestion_id.present? ? events_by_ingestion[ingestion_id.to_s] || [] : []

      acc[rate.id] = {
        source: rate.source,
        source_id: rate.source_id,
        source_label: rate.rate_source&.name,
        ingestion_id: ingestion_id,
        ingestion_status: ingestion&.status,
        upload_id: rate.source_upload_id,
        upload_status: upload&.status,
        created_by_id: rate.created_by_id,
        created_by_role: rate.created_by_role,
        created_at: rate.created_at,
        updated_at: rate.updated_at,
        placeholder_gap_id: rate.placeholder_gap&.id,
        placeholder_gap_status: rate.placeholder_gap&.status,
        events: events
      }
    end
  end

  def fx_events_by_ingestion(ingestion_ids)
    return {} if ingestion_ids.empty?

    ids = ingestion_ids.map(&:to_s)
    FxRateEvent.where("metadata ->> 'ingestion_id' IN (?)", ids)
      .order(created_at: :desc)
      .group_by { |event| event.metadata["ingestion_id"].to_s }
      .transform_values { |events| events.first(3) }
  end

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
