require "rails_helper"

RSpec.describe "Run verifications", type: :request do
  it "verifies input hash and persists verification fields" do
    input = {
      "schemaVersion" => "1.0",
      "trades" => [{"timestamp" => "2026-01-01T00:00:00Z", "seq" => 1}],
      "feeModel" => {"enabled" => true}
    }
    normalized = Runs::VerifyInputHash.new.send(:normalize_input, input)
    canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed.fetch("status")).to eq("verified")
    expect(parsed.fetch("runId")).to eq(run.id)
    expect(parsed.fetch("verificationStatus")).to eq("verified")
    expect(run.reload).to be_verified
  end

  it "returns forbidden when ADMIN_UI_TOKEN is set and token missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0", "trades" => []}, input_hash: "abc")

    post "/runs/#{run.id}/verify", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "allows verification when ADMIN_UI_TOKEN header is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    input = {
      "schemaVersion" => "1.0",
      "trades" => [{"timestamp" => "2026-01-01T00:00:00Z", "seq" => 1}],
      "feeModel" => {"enabled" => true}
    }
    normalized = Runs::VerifyInputHash.new.send(:normalize_input, input)
    canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", headers: {"X-Admin-Token" => "ui-secret"}, as: :json

    expect(response).to have_http_status(:ok)
    expect(run.reload).to be_verified
  end

  it "allows verification when ADMIN_UI_TOKEN is provided as bearer token" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    input = {
      "schemaVersion" => "1.0",
      "trades" => [{"timestamp" => "2026-01-01T00:00:00Z", "seq" => 1}],
      "feeModel" => {"enabled" => true}
    }
    normalized = Runs::VerifyInputHash.new.send(:normalize_input, input)
    canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", headers: {"Authorization" => "Bearer ui-secret"}, as: :json

    expect(response).to have_http_status(:ok)
    expect(run.reload).to be_verified
  end

  it "allows verification via operator role when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    input = {
      "schemaVersion" => "1.0",
      "trades" => [{"timestamp" => "2026-01-01T00:00:00Z", "seq" => 1}],
      "feeModel" => {"enabled" => true}
    }
    normalized = Runs::VerifyInputHash.new.send(:normalize_input, input)
    canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", headers: {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}, as: :json

    expect(response).to have_http_status(:ok)
    expect(run.reload).to be_verified
  end

  it "forbids verification via viewer role when operator role is required" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    input = {
      "schemaVersion" => "1.0",
      "trades" => [{"timestamp" => "2026-01-01T00:00:00Z", "seq" => 1}],
      "feeModel" => {"enabled" => true}
    }
    normalized = Runs::VerifyInputHash.new.send(:normalize_input, input)
    canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
    hash = FCS::Hashing::SHA256.hex(canonical)
    run = Run.create!(status: :succeeded, input_json: input, input_hash: hash)

    post "/runs/#{run.id}/verify", headers: {"X-Admin-User" => "viewer", "X-Admin-Role" => "viewer"}, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
