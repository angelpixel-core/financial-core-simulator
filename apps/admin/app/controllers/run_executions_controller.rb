class RunExecutionsController < ApplicationController
  include AdminUiAuthorizable

  before_action :load_run
  before_action :authorize_run_execution!

  def create
    if async_requested?
      RunExecutionJob.perform_later(@run.id, fee_enabled: fee_enabled?, explain: explain?, verbose: verbose?)
      payload = execution_payload(status: "enqueued")
    else
      Runs::Api.execute(run: @run, fee_enabled: fee_enabled?, explain: explain?, verbose: verbose?)
      payload = execution_payload(status: "executed")
    end

    respond_to do |format|
      format.json { render json: payload, status: :ok }
      format.html { redirect_back fallback_location: "/admin/resources/runs/#{@run.id}" }
    end
  rescue => e
    payload = execution_payload(status: "failed").merge("error" => e.message)

    respond_to do |format|
      format.json { render json: payload, status: :unprocessable_content }
      format.html do
        redirect_back fallback_location: "/admin/resources/runs/#{@run.id}", alert: e.message
      end
    end
  end

  private

  def authorize_run_execution!
    authorize_with_policy!(
      policy_class: RunPolicy,
      query: :execute?,
      record: @run,
      required_role: "operator",
      gate: :machine_or_session
    )
  end

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

  def execution_payload(status:)
    {
      "status" => status,
      "runId" => @run.id,
      "runStatus" => @run.reload.status
    }
  end
end
