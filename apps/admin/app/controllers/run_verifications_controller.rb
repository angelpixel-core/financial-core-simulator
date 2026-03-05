class RunVerificationsController < ApplicationController
  include AdminUiAuthorizable

  before_action :load_run
  before_action -> { authorize_admin_ui!(required_role: "operator") }

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
end
