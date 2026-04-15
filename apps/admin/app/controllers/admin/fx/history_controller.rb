# frozen_string_literal: true

class Admin::Fx::HistoryController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def index
    snapshot = Admin::Fx::Api.history_snapshot(sort_order: params[:sort])
    @supported_pairs = snapshot.fetch(:supported_pairs)
    @sort_order = snapshot.fetch(:sort_order)
    @rates_by_pair = snapshot.fetch(:rates_by_pair)
    @dates = snapshot.fetch(:dates)
    @empty_history = snapshot.fetch(:empty_history)
    session_upload_id = session[:fx_rate_upload_id]
    upload_active = session[:fx_rate_upload_active] == true
    @latest_upload = if upload_active && session_upload_id.present?
                       Admin::Fx::Api.visible_rate_upload(
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
                              Admin::Fx::Api.rate_upload_status_stream(account_id: current_admin_account&.id)
                            end
  end

  private

  def load_navigation_context
    @navigation_context = Runs::Api.navigation_context(params: params, session: session)
  end
end
