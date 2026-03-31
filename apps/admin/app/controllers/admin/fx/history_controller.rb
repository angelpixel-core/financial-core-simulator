# frozen_string_literal: true

class Admin::Fx::HistoryController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def index
    @supported_pairs = Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS
    @pair_entries = @supported_pairs.map do |base_currency, quote_currency|
      entries = FxDailyRate.where(base_currency: base_currency, quote_currency: quote_currency)
                           .order(operational_date: :desc)
      {
        base_currency: base_currency,
        quote_currency: quote_currency,
        entries: entries
      }
    end
    @empty_history = @pair_entries.all? { |entry| entry[:entries].blank? }
    @latest_upload = FxRateUpload.latest_for(account_id: current_admin_account&.id)
    @upload_status_stream = FxRateUpload.status_stream_for(account_id: current_admin_account&.id)
  end

  private

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
