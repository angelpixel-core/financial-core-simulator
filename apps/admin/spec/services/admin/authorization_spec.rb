require "rails_helper"
require "bcrypt"

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
    it "allows session-only gate when admin account session is present" do
      account = Account.create!(
        email: "session-viewer@example.com",
        status: :verified,
        password_hash: BCrypt::Password.create("secret-pass")
      )
      session_request = instance_double(
        ActionDispatch::Request,
        headers: {},
        session: { "admin_account_id" => account.id },
        params: {}
      )

      auth = described_class.new(request: session_request)

      expect(auth.allow_admin_session?(required_role: "viewer")).to be(true)
    end

    it "allows session-only gate when account_id session key is used" do
      account = Account.create!(
        email: "session-viewer-account-id@example.com",
        status: :verified,
        password_hash: BCrypt::Password.create("secret-pass")
      )
      session_request = instance_double(
        ActionDispatch::Request,
        headers: {},
        session: { "account_id" => account.id },
        params: {}
      )

      auth = described_class.new(request: session_request)

      expect(auth.allow_admin_session?(required_role: "viewer")).to be(true)
    end

    it "allows session-only gate when admin_account_id is a symbol key" do
      account = Account.create!(
        email: "session-viewer-symbol@example.com",
        status: :verified,
        password_hash: BCrypt::Password.create("secret-pass")
      )
      session_request = instance_double(
        ActionDispatch::Request,
        headers: {},
        session: { admin_account_id: account.id },
        params: {}
      )

      auth = described_class.new(request: session_request)

      expect(auth.allow_admin_session?(required_role: "viewer")).to be(true)
    end

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
