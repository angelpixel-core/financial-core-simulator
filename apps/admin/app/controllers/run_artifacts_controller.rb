# frozen_string_literal: true

class RunArtifactsController < ApplicationController
  before_action :load_run
  before_action :authorize_artifact_access!

  def result
    path = artifact_path_for(:result_json_path)
    return render plain: "Artifact not found", status: :not_found if path.nil?

    json = File.read(path)
    render json: JSON.parse(json)
  rescue JSON::ParserError
    send_file path, type: "application/json", disposition: "inline"
  end

  def positions
    path = artifact_path_for(:positions_csv_path)
    return render plain: "Artifact not found", status: :not_found if path.nil?

    send_file path, type: "text/csv", disposition: "attachment", filename: "positions.csv"
  end

  def pnl
    path = artifact_path_for(:pnl_csv_path)
    return render plain: "Artifact not found", status: :not_found if path.nil?

    send_file path, type: "text/csv", disposition: "attachment", filename: "pnl.csv"
  end

  private

  def load_run
    @run = Run.find(params[:id])
  end

  def authorize_artifact_access!
    return if @run.succeeded? && token_authorized?

    render plain: "Forbidden", status: :forbidden
  end

  def token_authorized?
    expected_token = ENV["ADMIN_ARTIFACTS_TOKEN"].to_s
    return true if expected_token.empty?

    provided_token = bearer_token.presence || request.headers["X-Admin-Artifact-Token"].to_s
    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  rescue ArgumentError
    false
  end

  def bearer_token
    auth_header = request.headers["Authorization"].to_s
    return nil unless auth_header.start_with?("Bearer ")

    auth_header.delete_prefix("Bearer ")
  end

  def artifact_path_for(attribute)
    raw_path = @run.public_send(attribute)
    return nil if raw_path.blank?

    expanded_path = File.expand_path(raw_path)
    storage_root = File.expand_path(Rails.root.join("storage", "runs"))
    allowed_prefix = "#{storage_root}#{File::SEPARATOR}"

    return nil unless expanded_path.start_with?(allowed_prefix)
    return nil unless File.file?(expanded_path)

    expanded_path
  end
end
