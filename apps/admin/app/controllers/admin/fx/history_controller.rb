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

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
