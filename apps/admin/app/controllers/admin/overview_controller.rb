class Admin::OverviewController < ApplicationController
  before_action :authorize_admin_ui!

  def show
    @metrics = dashboard_metrics
  end

  def top_accounts
    @metrics = dashboard_metrics
    if request.xhr?
      render partial: "admin/overview/top_accounts", locals: { metrics: @metrics }
    else
      render :top_accounts
    end
  end

  private

  def authorize_admin_ui!
    auth = Admin::Authorization.new(request: request)
    return if auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")

    render plain: "Forbidden", status: :forbidden
  end

  def dashboard_metrics
    Admin::DashboardMetrics.new.call
  end
end
