class RunVerificationsController < ApplicationController
  before_action :load_run
  before_action :authorize_admin_ui!

  def create
    result = Runs::VerifyInputHash.new.call(@run)

    respond_to do |format|
      format.json { render json: result, status: :ok }
      format.html { redirect_back fallback_location: "/admin/resources/runs/#{@run.id}" }
    end
  end

  private

  def load_run
    @run = Run.find(params[:id])
  end

  def authorize_admin_ui!
    auth = Admin::Authorization.new(request: request)
    return if auth.allow?(required_role: "operator", token_key: "ADMIN_UI_TOKEN")

    render plain: "Forbidden", status: :forbidden
  end
end
