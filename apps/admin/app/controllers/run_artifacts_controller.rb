# frozen_string_literal: true

class RunArtifactsController < ApplicationController
  # Si luego activás auth, acá podés meter before_action :authenticate_user! o similar.

  def result
    run = Run.find(params[:id])
    path = run.result_json_path

    return render plain: "Artifact not found", status: :not_found if path.blank? || !File.exist?(path)

    json = File.read(path)

    # render JSON pretty para lectura humana
    render json: JSON.parse(json)
  rescue JSON::ParserError
    # si por alguna razón el file no es JSON válido
    send_file path, type: "application/json", disposition: "inline"
  end

  def positions
    run = Run.find(params[:id])
    path = run.positions_csv_path

    return render plain: "Artifact not found", status: :not_found if path.blank? || !File.exist?(path)

    send_file path, type: "text/csv", disposition: "attachment", filename: "positions.csv"
  end

  def pnl
    run = Run.find(params[:id])
    path = run.pnl_csv_path

    return render plain: "Artifact not found", status: :not_found if path.blank? || !File.exist?(path)

    send_file path, type: "text/csv", disposition: "attachment", filename: "pnl.csv"
  end
end
