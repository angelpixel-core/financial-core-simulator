class RunExecutionsController < ApplicationController
  include AdminUiAuthorizable

  before_action :load_run
  before_action -> { authorize_admin_ui!(required_role: "operator") }

  def create
    if async_requested?
      RunExecutionJob.perform_later(@run.id, fee_enabled: fee_enabled?, explain: explain?, verbose: verbose?)
      payload = { status: "enqueued", run_id: @run.id }
    else
      Runs::Execute.new.call(@run, fee_enabled: fee_enabled?, explain: explain?, verbose: verbose?)
      payload = { status: "executed", run_id: @run.id }
    end

    respond_to do |format|
      format.json { render json: payload, status: :ok }
      format.html { redirect_back fallback_location: "/admin/resources/runs/#{@run.id}" }
    end
  end

  private

  def load_run
    @run = Run.find(params[:id])
  end

  def async_requested?
    params[:async].to_s == "1"
  end

  def fee_enabled?
    parse_boolean(params.fetch(:fee_enabled, true))
  end

  def explain?
    parse_boolean(params.fetch(:explain, true))
  end

  def verbose?
    parse_boolean(params.fetch(:verbose, false))
  end

  def parse_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
