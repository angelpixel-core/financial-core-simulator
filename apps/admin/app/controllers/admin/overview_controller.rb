class Admin::OverviewController < ApplicationController
  before_action :authorize_admin_ui!

  def show
    @metrics = dashboard_metrics
    @ingestion_validation_errors = dashboard_ingestion_validation_errors
  end

  def top_accounts
    @metrics = dashboard_metrics
    if request.xhr?
      render partial: "admin/overview/top_accounts", locals: { metrics: @metrics }
    else
      render :top_accounts
    end
  end

  def ingestion_validation_errors
    render json: { errors: dashboard_ingestion_validation_errors }, status: :ok
  end

  def ingestion_validation_errors_panel
    @errors = dashboard_ingestion_validation_errors
    if request.xhr?
      render partial: "admin/overview/ingestion_validation_errors", locals: { errors: @errors }
    else
      render :ingestion_validation_errors
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

  def dashboard_ingestion_validation_errors
    Admin::DashboardMetrics.new.ingestion_validation_errors
  end
end
