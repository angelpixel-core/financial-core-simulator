# frozen_string_literal: true

class Admin::Fx::HistoryController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def index
    @supported_pairs = Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS
    @sort_order = params[:sort].to_s == 'asc' ? 'asc' : 'desc'
    @rates_by_pair = @supported_pairs.to_h do |base_currency, quote_currency|
      ["#{base_currency}/#{quote_currency}", {}]
    end
    rates = FxDailyRate.where(*supported_pair_conditions)
                       .order(operational_date: @sort_order)
                       .to_a
    placeholder_rates = rates.select(&:placeholder?)
    if placeholder_rates.any?
      ActiveRecord::Associations::Preloader.new(
        records: placeholder_rates,
        associations: :placeholder_gap
      ).call
    end
    @dates = rates.map(&:operational_date).uniq
    @dates.sort!
    @dates.reverse! if @sort_order == 'desc'
    rates.each do |rate|
      @rates_by_pair["#{rate.base_currency}/#{rate.quote_currency}"][rate.operational_date] = rate
    end
    @empty_history = @dates.blank?
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
    @upload_status_stream = @latest_upload&.processing_status? ? FxRateUpload.status_stream_for(account_id: current_admin_account&.id) : nil
  end

  private

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end

  def supported_pair_conditions
    statement = @supported_pairs.map { '(base_currency = ? AND quote_currency = ?)' }.join(' OR ')
    [statement, *@supported_pairs.flatten]
  end
end
