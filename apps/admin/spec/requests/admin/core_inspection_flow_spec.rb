require "rails_helper"
require "fileutils"

RSpec.describe "Admin core inspection flow", type: :request do
  around do |example|
    I18n.with_locale(:es) { example.run }
  end

  it "covers overview to artifacts traversal across mobile/tablet/desktop widths" do
    base_dir = Rails.root.join("storage", "runs", "spec_flow_artifacts")
    FileUtils.mkdir_p(base_dir)
    result_path = base_dir.join("result.json")
    positions_path = base_dir.join("positions.csv")
    pnl_path = base_dir.join("pnl.csv")
    File.write(result_path, '{"accounts":[]}')
    File.write(positions_path, "account,qty\nacc-1,10\n")
    File.write(pnl_path, "account,total\nacc-1,12\n")

    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: "hash-flow",
      schema_version: "1.0",
      engine_version: "1.0",
      artifacts: {
        "result_json_path" => result_path.to_s,
        "positions_csv_path" => positions_path.to_s,
        "pnl_csv_path" => pnl_path.to_s
      }
    )

    [375, 834, 1280].each do |viewport_width|
      headers = admin_session_headers.merge("X-Viewport-Width" => viewport_width.to_s)
      context = {
        selected_run: run.id,
        run_status: "succeeded",
        validation_status: "verified",
        date_range: "last_7d",
        correlation_id: "corr-flow",
        locale: "es"
      }

      get "/admin/overview", params: context, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.overview.hero.open_latest_reliable"))

      avo_headers = headers.merge("X-Admin-Role" => "admin")
      get "/admin/resources/runs/#{run.id}", params: context, headers: avo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.runs.artifacts.title"))

      get "/runs/#{run.id}/positions", params: context.merge(preview: 1), headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Back to run details")
      expect(response.body).to include("selected_run=#{run.id}")
    end
  ensure
    FileUtils.rm_f(result_path) if defined?(result_path)
    FileUtils.rm_f(positions_path) if defined?(positions_path)
    FileUtils.rm_f(pnl_path) if defined?(pnl_path)
  end

  def admin_session_headers
    {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}
  end
end
