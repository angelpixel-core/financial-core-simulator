class Admin::OverviewController < ApplicationController
  def show
    @metrics = Admin::DashboardMetrics.new.call
  end
end
