require "rails_helper"
require "fileutils"
require "nokogiri"

RSpec.describe "Admin keyboard navigation flow", type: :request do
  it "supports state-first navigation from overview to run detail, validation, and artifacts" do
    base_dir = Rails.root.join("storage", "runs", "spec_keyboard_flow")
    FileUtils.mkdir_p(base_dir)
    result_path = base_dir.join("result.json")
    File.write(result_path, "{\"accounts\":[]}")

    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: "hash-keyboard",
      artifacts: { "result_json_path" => result_path.to_s }
    )

    context = {
      selected_run: run.id,
      run_status: "succeeded",
      validation_status: "verified",
      date_range: "last_7d",
      correlation_id: "corr-kbd"
    }

    get "/admin/overview", params: context, headers: admin_session_headers
    expect(response).to have_http_status(:ok)

    doc = Nokogiri::HTML(response.body)
    nav = doc.at_css(".app-shell__nav")
    links = nav.css("a")

    labels = links.map { |link| link.text.strip }
    expect(labels).to include("Overview", "Runs", "Validation", "Artifacts")

    overview_link = links.find { |node| node.text.strip == "Overview" }
    runs_link = links.find { |node| node.text.strip == "Runs" }
    validation_link = links.find { |node| node.text.strip == "Validation" }
    artifacts_link = links.find { |node| node.text.strip == "Artifacts" }

    expect(overview_link["aria-current"].delete('"')).to eq("page")

    get runs_link["href"], headers: admin_session_headers
    expect(response).to have_http_status(:ok)

    get validation_link["href"], params: context, headers: admin_session_headers
    expect(response).to have_http_status(:ok)

    get artifacts_link["href"], params: context, headers: admin_session_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("accounts")
  ensure
    FileUtils.rm_f(result_path) if defined?(result_path)
  end

  def admin_session_headers
    { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }
  end
end
