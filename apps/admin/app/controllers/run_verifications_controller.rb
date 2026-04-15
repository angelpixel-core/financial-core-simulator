class RunVerificationsController < ApplicationController
  include AdminUiAuthorizable

  before_action :load_run
  before_action :authorize_run_verification!

  def create
    result = Runs::Api.verify_input_hash(run: @run)
    payload = verification_payload(result)

    respond_to do |format|
      format.json { render json: payload, status: :ok }
      format.html { redirect_back fallback_location: "/admin/resources/runs/#{@run.id}" }
    end
  rescue StandardError => e
    payload = verification_payload({ 'status' => 'verification_error', 'error' => e.message })

    respond_to do |format|
      format.json { render json: payload, status: :unprocessable_content }
      format.html do
        redirect_back fallback_location: "/admin/resources/runs/#{@run.id}", alert: e.message
      end
    end
  end

  private

  def authorize_run_verification!
    authorize_machine_or_session_operator!
  end

  def load_run
    @run = Run.find(params[:id])
  end

  def verification_payload(result)
    normalized = result.respond_to?(:deep_stringify_keys) ? result.deep_stringify_keys : result

    normalized.merge(
      'runId' => @run.id,
      'verificationStatus' => @run.reload.verification_status
    )
  end
end
