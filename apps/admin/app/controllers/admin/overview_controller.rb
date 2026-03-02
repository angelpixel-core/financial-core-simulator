class Admin::OverviewController < ApplicationController
  include TokenAuthorization

  before_action :authorize_admin_ui!

  def show
    @metrics = Admin::DashboardMetrics.new.call
  end

  def top_accounts
    @metrics = Admin::DashboardMetrics.new.call
    render partial: "admin/overview/top_accounts", locals: { metrics: @metrics }
  end

  private

  def authorize_admin_ui!
    return if token_authorized_for?("ADMIN_UI_TOKEN")

    render plain: "Forbidden", status: :forbidden
  end
end
