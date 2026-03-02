class Admin::ComponentComparisonsController < ApplicationController
  before_action :authorize_admin_ui!

  def show
    @metrics = Admin::DashboardMetrics.new.call
    @card_title = "Success rate (last 50)"
    @card_value = "#{@metrics[:success_rate_last_50]}%"
    @card_info = "runs 7d: #{@metrics[:total_runs_7d]} • runs 30d: #{@metrics[:total_runs_30d]}"
  end

  private

  def authorize_admin_ui!
    auth = Admin::Authorization.new(request: request)
    return if auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")

    render plain: "Forbidden", status: :forbidden
  end
end
