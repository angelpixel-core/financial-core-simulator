class Admin::ComponentComparisonsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!

  def show
    @metrics = Admin::DashboardMetrics.new.call
    @card_title = "Success rate (last 50)"
    @card_value = "#{@metrics[:success_rate_last_50]}%"
    @card_info = "runs 7d: #{@metrics[:total_runs_7d]} • runs 30d: #{@metrics[:total_runs_30d]}"
  end
end
