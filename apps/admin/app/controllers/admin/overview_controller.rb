class Admin::OverviewController < ApplicationController
  def show
    @metrics = Admin::DashboardMetrics.new.call
  end

  def top_accounts
    @metrics = Admin::DashboardMetrics.new.call
    render partial: "admin/overview/top_accounts", locals: { metrics: @metrics }
  end
end
