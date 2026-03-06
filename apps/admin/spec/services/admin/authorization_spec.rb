require "rails_helper"

RSpec.describe Admin::Authorization do
  let(:request) { ActionDispatch::TestRequest.create }

  before do
    allow(ENV).to receive(:[]).and_call_original
  end

  it "allows when token is not configured" do
    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
  end

  it "allows when token matches" do
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
    request.headers["X-Admin-Token"] = "ui-secret"

    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
  end

  it "allows when bearer token matches ADMIN_UI_TOKEN" do
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
    request.headers["Authorization"] = "Bearer ui-secret"

    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
  end

  it "allows role-based access when role meets requirement" do
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
    request.headers["X-Admin-User"] = "ops"
    request.headers["X-Admin-Role"] = "operator"

    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
    expect(auth.allow?(required_role: "operator", token_key: "ADMIN_UI_TOKEN")).to be(true)
    expect(auth.allow?(required_role: "admin", token_key: "ADMIN_UI_TOKEN")).to be(false)
  end

  it "enforces role threshold order across viewer, operator, and admin" do
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
    request.headers["X-Admin-User"] = "admin-user"
    request.headers["X-Admin-Role"] = "admin"

    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
    expect(auth.allow?(required_role: "operator", token_key: "ADMIN_UI_TOKEN")).to be(true)
    expect(auth.allow?(required_role: "admin", token_key: "ADMIN_UI_TOKEN")).to be(true)
  end

  it "does not accept artifact token header for ADMIN_UI_TOKEN checks" do
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
    request.headers["X-Admin-Artifact-Token"] = "ui-secret"

    auth = described_class.new(request: request)

    expect(auth.allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(false)
  end

  describe "explicit gate split contract" do
    it "enforces role thresholds for session-only gate" do
      request.headers["X-Admin-User"] = "ops-session"
      request.headers["X-Admin-Role"] = "operator"

      auth = described_class.new(request: request)

      expect(auth.allow_admin_session?(required_role: "viewer")).to be(true)
      expect(auth.allow_admin_session?(required_role: "operator")).to be(true)
      expect(auth.allow_admin_session?(required_role: "admin")).to be(false)
    end

    it "allows machine-or-session gate with valid machine token" do
      allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")
      request.headers["X-Admin-Token"] = "ui-secret"

      auth = described_class.new(request: request)

      expect(auth.allow_machine_or_session?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(true)
    end

    it "denies machine-or-session gate when no valid session or machine token exists" do
      allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

      auth = described_class.new(request: request)

      expect(auth.allow_machine_or_session?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")).to be(false)
    end
  end
end
