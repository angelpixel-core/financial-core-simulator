require "rails_helper"
require "bcrypt"
require "fileutils"
require "json"
require "tmpdir"

RSpec.describe "Run artifacts", type: :request do
  it "serves result.json when artifact path is under storage/runs" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq({"ok" => true})
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "returns not_found when artifact path is outside storage/runs" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    Dir.mktmpdir do |dir|
      outside_path = File.join(dir, "result.json")
      File.write(outside_path, JSON.generate({leaked: true}))
      run.update!(artifacts: {"result_json_path" => outside_path})

      get "/runs/#{run.id}/result"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Artifact not found")
    end
  end

  it "redirects to root when run status is not succeeded" do
    run = Run.create!(status: :running, input_json: {"schemaVersion" => "1.0"})

    get "/runs/#{run.id}/result"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "redirects to root when token is configured and not provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "serves artifact when configured token is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-ok.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"Authorization" => "Bearer secret-token"}

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq({"ok" => true})
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "serves artifact when configured token is provided via X-Admin-Artifact-Token" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-header.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"X-Admin-Artifact-Token" => "secret-token"}

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq({"ok" => true})
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "redirects to root when only X-Admin-Token is provided for artifact access" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-ui-header.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"X-Admin-Token" => "secret-token"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "redirects to root when bearer token value does not match ADMIN_ARTIFACTS_TOKEN" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("artifact-secret")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-mismatch.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"Authorization" => "Bearer ui-secret"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "serves artifact when operator role header is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-operator-role.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq({"ok" => true})
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "serves artifact for operator session while artifact token is configured" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-operator-session.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq({"ok" => true})
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "redirects to root when only viewer role header is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-viewer-role.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"X-Admin-User" => "viewer", "X-Admin-Role" => "viewer"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "redirects to root for unsupported basic authorization mechanism" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")

    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-token-basic-auth.json")
    File.write(path, JSON.generate({ok: true}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/result", headers: {"Authorization" => "Basic c2VjcmV0LXRva2Vu"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "renders CSV preview inline when preview=1 is passed" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("positions.csv")
    File.write(path, "account,qty\nacc-1,10\n")

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"positions_csv_path" => path.to_s}
    )

    get "/runs/#{run.id}/positions", params: {preview: 1}

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("CSV Preview")
    expect(response.body).to include("<table")
    expect(response.body).to include("account")
    expect(response.body).to include("acc-1")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "preserves navigation context in positions preview return link" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("positions-context.csv")
    File.write(path, "account,qty\nacc-1,10\n")

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"positions_csv_path" => path.to_s}
    )

    get "/runs/#{run.id}/positions", params: {
      preview: 1,
      selected_run: run.id,
      run_status: "succeeded",
      validation_status: "verified",
      date_range: "last_7d",
      correlation_id: "corr-pos"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Back to run details")
    expect(response.body).to include("selected_run=#{run.id}")
    expect(response.body).to include("run_status=succeeded")
    expect(response.body).to include("validation_status=verified")
    expect(response.body).to include("date_range=last_7d")
    expect(response.body).to include("correlation_id=corr-pos")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "preserves navigation context in pnl preview return link" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("pnl-context.csv")
    File.write(path, "account,total\nacc-1,12\n")

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"pnl_csv_path" => path.to_s}
    )

    get "/runs/#{run.id}/pnl", params: {
      preview: 1,
      selected_run: run.id,
      run_status: "failed",
      validation_status: "warning",
      date_range: "last_24h",
      correlation_id: "corr-pnl"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Back to run details")
    expect(response.body).to include("selected_run=#{run.id}")
    expect(response.body).to include("run_status=failed")
    expect(response.body).to include("validation_status=warning")
    expect(response.body).to include("date_range=last_24h")
    expect(response.body).to include("correlation_id=corr-pnl")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "renders risk view table from result.json" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-risk.json")
    File.write(path, JSON.generate(
      {
        "accounts" => [
          {
            "accountId" => "acc-1",
            "risk" => {
              "status" => "LIQUIDATABLE",
              "marginRatio" => "0.900000000000000000"
            },
            "riskEvents" => [
              {
                "type" => "RISK_LIQUIDATION_CANDIDATE",
                "reasonCode" => "ERR_RISK_LIQUIDATABLE",
                "marketId" => "BTC-USD",
                "seq" => 12,
                "severity" => "100"
              }
            ]
          }
        ]
      }
    ))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/risk"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Risk View")
    expect(response.body).to include("acc-1")
    expect(response.body).to include("LIQUIDATABLE")
    expect(response.body).to include("0.900000000000000000")
    expect(response.body).to include("ERR_RISK_LIQUIDATABLE")
    expect(response.body).to include("badge--liquidatable")
    expect(response.body).to include("Status filter")
    expect(response.body).to include("ALL: 1")
    expect(response.body).to include("LIQUIDATABLE: 1")
    expect(response.body).to include("Risk distribution")
    expect(response.body).to include("aria-label=\"risk-pie-chart\"")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "filters risk view by status" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-risk-filter.json")
    File.write(path, JSON.generate(
      {
        "accounts" => [
          {
            "accountId" => "acc-healthy",
            "risk" => {
              "status" => "HEALTHY",
              "marginRatio" => "1.500000000000000000"
            },
            "riskEvents" => []
          },
          {
            "accountId" => "acc-mc",
            "risk" => {
              "status" => "MARGIN_CALL",
              "marginRatio" => "0.950000000000000000"
            },
            "riskEvents" => []
          }
        ]
      }
    ))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/risk", params: {status: "MARGIN_CALL"}

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("acc-mc")
    expect(response.body).to include("badge--margin-call")
    expect(response.body).not_to include("acc-healthy")
    expect(response.body).to include("ALL: 2")
    expect(response.body).to include("HEALTHY: 1")
    expect(response.body).to include("MARGIN_CALL: 1")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "renders context-preserving return link in risk drilldown" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result-risk-context.json")
    File.write(path, JSON.generate({"accounts" => []}))

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      input_hash: "hash-context",
      artifacts: {"result_json_path" => path.to_s}
    )

    get "/runs/#{run.id}/risk", params: {
      selected_run: run.id,
      run_status: "succeeded",
      validation_status: "verified",
      date_range: "last_7d",
      correlation_id: "corr-ctx"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Back to run details")
    expect(response.body).to include("selected_run=#{run.id}")
    expect(response.body).to include("run_status=succeeded")
    expect(response.body).to include("validation_status=verified")
    expect(response.body).to include("date_range=last_7d")
    expect(response.body).to include("correlation_id=corr-ctx")
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end
end
