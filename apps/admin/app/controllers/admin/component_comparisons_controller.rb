class Admin::ComponentComparisonsController < ApplicationController
  def show
    @metrics = Admin::DashboardMetrics.new.call
    @card_title = "Success rate (last 50)"
    @card_value = "#{@metrics[:success_rate_last_50]}%"
    @card_info = "runs 7d: #{@metrics[:total_runs_7d]} • runs 30d: #{@metrics[:total_runs_30d]}"
  end
end
