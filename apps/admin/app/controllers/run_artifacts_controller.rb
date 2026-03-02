# frozen_string_literal: true

class RunArtifactsController < ApplicationController
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

  def artifact_path_for(attribute)
    run = Run.find(params[:id])
    raw_path = run.public_send(attribute)
    return nil if raw_path.blank?

    expanded_path = File.expand_path(raw_path)
    storage_root = File.expand_path(Rails.root.join("storage", "runs"))
    allowed_prefix = "#{storage_root}#{File::SEPARATOR}"

    return nil unless expanded_path.start_with?(allowed_prefix)
    return nil unless File.file?(expanded_path)

    expanded_path
  end
end
