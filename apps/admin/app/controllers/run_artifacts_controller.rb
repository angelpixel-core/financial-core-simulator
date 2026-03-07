# frozen_string_literal: true

class RunArtifactsController < ApplicationController
  RISK_STATUSES = [ "HEALTHY", "MARGIN_CALL", "LIQUIDATABLE" ].freeze

  require "csv"
  require "cgi"
  require "json"

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

  def risk
    path = artifact_path_for(:result_json_path)
    return render plain: "Artifact not found", status: :not_found if path.nil?

    payload = JSON.parse(File.read(path))
    status_filter = normalize_status_filter(params[:status])
    all_rows = extract_risk_rows(payload)
    rows = filter_risk_rows(all_rows, status_filter)
    counters = risk_status_counters(all_rows)
    render html: risk_table_html(rows, status_filter: status_filter, counters: counters).html_safe
  rescue JSON::ParserError
    render plain: "Invalid result.json artifact", status: :unprocessable_entity
  end

  private

  def load_run
    @run = Run.find(params[:id])
  end

  def authorize_artifact_access!
    return if artifact_access_policy.allowed?

    if request.format.html?
      redirect_to root_path
    else
      render plain: "Forbidden", status: :forbidden
    end
  end

  def artifact_access_policy
    @artifact_access_policy ||= Artifacts::AccessPolicy.new(run: @run, request: request)
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

  def extract_risk_rows(payload)
    accounts = payload.is_a?(Hash) ? payload.fetch("accounts", []) : []
    return [] unless accounts.is_a?(Array)

    accounts.map do |account|
      risk = account.fetch("risk", {})
      events = account.fetch("riskEvents", [])

      {
        account_id: account.fetch("accountId", "-"),
        status: risk.fetch("status", "-"),
        margin_ratio: risk.fetch("marginRatio", "-"),
        events: events.is_a?(Array) ? events : []
      }
    end
  end

  def risk_table_html(rows, status_filter:, counters:)
    body_rows = rows.map do |row|
      events_html = risk_events_html(row.fetch(:events))
      status_badge = risk_status_badge_html(row.fetch(:status))

      "<tr>" \
        "<td>#{h(row.fetch(:account_id))}</td>" \
        "<td>#{status_badge}</td>" \
        "<td>#{h(row.fetch(:margin_ratio))}</td>" \
        "<td>#{events_html}</td>" \
      "</tr>"
    end.join

    body_rows = "<tr><td colspan=\"4\" style=\"padding: 10px; color: #4a5568;\">No accounts for selected filter.</td></tr>" if body_rows.empty?

    options = [ "ALL" ] + RISK_STATUSES
    option_html = options.map do |status|
      selected = status == status_filter ? " selected" : ""
      "<option value=\"#{h(status)}\"#{selected}>#{h(status)}</option>"
    end.join

    summary_chips = options.map do |status|
      key = status == "ALL" ? "ALL" : status
      value = counters.fetch(key, 0)
      "<span style=\"display:inline-block;padding:4px 10px;border-radius:999px;background:#edf2f7;color:#1a202c;font-weight:600;\">#{h(status)}: #{value}</span>"
    end.join(" ")

    pie_chart = risk_pie_chart_html(counters)

    <<~HTML
      <main style="font-family: 'IBM Plex Sans', 'Inter', sans-serif; padding: 16px;">
        <h1 style="margin-top: 0;">Risk View</h1>
        <p style="margin-top: 0; color: #4a5568;">Per-account risk status, margin ratio, and emitted risk events.</p>
        <section style="margin-bottom: 12px; display: flex; flex-wrap: wrap; gap: 8px;">#{summary_chips}</section>
        #{pie_chart}
        <form method="get" style="margin-bottom: 12px; display: flex; gap: 8px; align-items: center;">
          <label for="status" style="font-weight: 600;">Status filter</label>
          <select id="status" name="status" style="padding: 4px 8px; border: 1px solid #cbd5e0; border-radius: 6px;">#{option_html}</select>
          <button type="submit" style="padding: 4px 10px; border: 1px solid #1a202c; border-radius: 6px; background: #1a202c; color: #fff;">Apply</button>
        </form>
        <table style="width: 100%; border-collapse: collapse;">
          <thead style="background: #f2f4f8;">
            <tr>
              <th style="text-align: left;">Account</th>
              <th style="text-align: left;">Status</th>
              <th style="text-align: left;">Margin Ratio</th>
              <th style="text-align: left;">Events</th>
            </tr>
          </thead>
          <tbody>#{body_rows}</tbody>
        </table>
      </main>
    HTML
  end

  def risk_events_html(events)
    return "-" if events.empty?

    items = events.map do |event|
      "<li>" \
        "<strong>#{h(event.fetch('reasonCode', '-'))}</strong>" \
        " - type: #{h(event.fetch('type', '-'))}, market: #{h(event.fetch('marketId', '-'))}, seq: #{h(event.fetch('seq', '-'))}, severity: #{h(event.fetch('severity', '-'))}" \
      "</li>"
    end.join

    "<ul style=\"margin: 0; padding-left: 16px;\">#{items}</ul>"
  end

  def risk_status_badge_html(status)
    css_class, bg, fg = case status
    when "HEALTHY"
                          [ "badge--healthy", "#e6fffa", "#0f766e" ]
    when "MARGIN_CALL"
                          [ "badge--margin-call", "#fff7ed", "#c2410c" ]
    when "LIQUIDATABLE"
                          [ "badge--liquidatable", "#fee2e2", "#b91c1c" ]
    else
                          [ "badge--unknown", "#edf2f7", "#2d3748" ]
    end

    "<span class=\"#{css_class}\" style=\"display:inline-block;padding:2px 8px;border-radius:999px;font-weight:600;background:#{bg};color:#{fg};\">#{h(status)}</span>"
  end

  def normalize_status_filter(value)
    candidate = value.to_s.upcase
    return "ALL" if candidate.empty?
    return candidate if candidate == "ALL"
    return candidate if RISK_STATUSES.include?(candidate)

    "ALL"
  end

  def filter_risk_rows(rows, status_filter)
    return rows if status_filter == "ALL"

    rows.select { |row| row.fetch(:status) == status_filter }
  end

  def risk_status_counters(rows)
    counts = {
      "ALL" => rows.size,
      "HEALTHY" => 0,
      "MARGIN_CALL" => 0,
      "LIQUIDATABLE" => 0
    }

    rows.each do |row|
      status = row.fetch(:status)
      counts[status] += 1 if counts.key?(status)
    end

    counts
  end

  def risk_pie_chart_html(counters)
    total = counters.fetch("ALL", 0)
    return "<section style=\"margin-bottom: 12px; color: #4a5568;\">Risk distribution: no data</section>" if total.zero?

    healthy = counters.fetch("HEALTHY", 0)
    margin_call = counters.fetch("MARGIN_CALL", 0)
    liquidatable = counters.fetch("LIQUIDATABLE", 0)

    healthy_pct = (healthy.to_f / total * 100).round(2)
    margin_call_pct = (margin_call.to_f / total * 100).round(2)
    liquidatable_pct = (liquidatable.to_f / total * 100).round(2)

    stop_a = healthy_pct
    stop_b = healthy_pct + margin_call_pct

    <<~HTML
      <section style="margin-bottom: 14px; display: flex; gap: 14px; align-items: center;">
        <div aria-label="risk-pie-chart" style="width: 120px; height: 120px; border-radius: 50%; border: 1px solid #cbd5e0; background: conic-gradient(#0f766e 0% #{stop_a}%, #c2410c #{stop_a}% #{stop_b}%, #b91c1c #{stop_b}% 100%);"></div>
        <div>
          <div style="font-weight: 700; margin-bottom: 4px;">Risk distribution</div>
          <div style="color:#0f766e;">HEALTHY: #{healthy} (#{format('%.2f', healthy_pct)}%)</div>
          <div style="color:#c2410c;">MARGIN_CALL: #{margin_call} (#{format('%.2f', margin_call_pct)}%)</div>
          <div style="color:#b91c1c;">LIQUIDATABLE: #{liquidatable} (#{format('%.2f', liquidatable_pct)}%)</div>
        </div>
      </section>
    HTML
  end

  def h(value)
    CGI.escapeHTML(value.to_s)
  end
end
