require "rails_helper"

RSpec.describe Artifacts::AccessPolicy do
  let(:request) { ActionDispatch::TestRequest.create }

  before do
    allow(ENV).to receive(:[]).and_call_original
  end

  it "allows access for succeeded run when token is not configured" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(true)
  end

  it "denies access when run status is not succeeded" do
    run = Run.create!(status: :running, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(false)
  end

  it "denies access when token is configured and missing" do
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(false)
  end

  it "allows access when bearer token matches configured token" do
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")
    request.headers["Authorization"] = "Bearer secret-token"
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(true)
  end

  it "allows access when operator role headers are provided" do
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")
    request.headers["X-Admin-User"] = "operator-user"
    request.headers["X-Admin-Role"] = "operator"
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(true)
  end

  it "denies access when only viewer role headers are provided" do
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")
    request.headers["X-Admin-User"] = "viewer-user"
    request.headers["X-Admin-Role"] = "viewer"
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(false)
  end

  it "denies access when only X-Admin-Token is provided for artifacts" do
    allow(ENV).to receive(:[]).with("ADMIN_ARTIFACTS_TOKEN").and_return("secret-token")
    request.headers["X-Admin-Token"] = "secret-token"
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    policy = described_class.new(run: run, request: request)

    expect(policy.allowed?).to be(false)
  end
end
