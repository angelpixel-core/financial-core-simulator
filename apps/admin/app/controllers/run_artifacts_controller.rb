# frozen_string_literal: true

class RunArtifactsController < ApplicationController
  require "csv"
  require "cgi"

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

    return render_csv_preview(path) if preview_requested?

    send_file path, type: "text/csv", disposition: "attachment", filename: "positions.csv"
  end

  def pnl
    path = artifact_path_for(:pnl_csv_path)
    return render plain: "Artifact not found", status: :not_found if path.nil?

    return render_csv_preview(path) if preview_requested?

    send_file path, type: "text/csv", disposition: "attachment", filename: "pnl.csv"
  end

  private

  def load_run
    @run = Run.find(params[:id])
  end

  def authorize_artifact_access!
    policy = Artifacts::AccessPolicy.new(run: @run, request: request)
    return if policy.allowed?

    render plain: "Forbidden", status: :forbidden
  end

  def preview_requested?
    params[:preview].to_s == "1"
  end

  def render_csv_preview(path)
    table_html = csv_preview_table(path)
    render html: table_html.html_safe
  end

  def csv_preview_table(path)
    csv = CSV.read(path, headers: true)
    headers = csv.headers || []
    rows = csv.first(100)

    header_cells = headers.map { |cell| "<th>#{CGI.escapeHTML(cell.to_s)}</th>" }.join
    body_rows = rows.map do |row|
      values = headers.map { |header| "<td>#{CGI.escapeHTML(row[header].to_s)}</td>" }.join
      "<tr>#{values}</tr>"
    end.join

    <<~HTML
      <main style="font-family: 'IBM Plex Sans', 'Inter', sans-serif; padding: 16px;">
        <h1 style="margin-top: 0;">CSV Preview: #{CGI.escapeHTML(File.basename(path))}</h1>
        <table style="width: 100%; border-collapse: collapse;">
          <thead style="background: #f2f4f8;"><tr>#{header_cells}</tr></thead>
          <tbody>#{body_rows}</tbody>
        </table>
      </main>
    HTML
  end

  def artifact_path_for(attribute)
    Artifacts::PathResolver.new(run: @run, attribute: attribute).call
  end
end
