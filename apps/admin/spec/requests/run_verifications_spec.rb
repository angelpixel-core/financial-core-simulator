require "rails_helper"

RSpec.describe "Run verifications", type: :request do
  it "verifies input hash and persists verification fields" do
    input = {
      "schemaVersion" => "1.0",
      "trades" => [ { "timestamp" => "2026-01-01T00:00:00Z", "seq" => 1 } ],
      "feeModel" => { "enabled" => true }
    }
    canonical = FCS::Hashing::CanonicalJSON.dump(input)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("status")).to eq("verified")
    expect(run.reload).to be_verified
  end

  it "returns forbidden when ADMIN_UI_TOKEN is set and token missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0", "trades" => [] }, input_hash: "abc")

    post "/runs/#{run.id}/verify", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "allows verification when ADMIN_UI_TOKEN header is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    input = {
      "schemaVersion" => "1.0",
      "trades" => [ { "timestamp" => "2026-01-01T00:00:00Z", "seq" => 1 } ],
      "feeModel" => { "enabled" => true }
    }
    canonical = FCS::Hashing::CanonicalJSON.dump(input)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", headers: { "X-Admin-Token" => "ui-secret" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(run.reload).to be_verified
  end
end
