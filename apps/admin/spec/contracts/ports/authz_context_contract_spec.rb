require "rails_helper"
require "bcrypt"

RSpec.describe "Authz context port contract" do
  it "is satisfied by access control authz context adapter" do
    request = ActionDispatch::TestRequest.create
    request.path = "/admin/system-health"
    request.request_method = "GET"

    account = Account.create!(
      email: "contract-authz@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    adapter = Admin::AccessControl::AuthzContextAdapter.new(request: request)

    expect(adapter).to be_a(FCS::Ports::AuthzContext)

    context = adapter.call(
      account: account,
      role: "operator",
      required_role: "viewer",
      gate: "session"
    )

    expect(context).to include(
      account_id: account.id.to_s,
      account_email: account.email,
      role: "operator",
      required_role: "viewer",
      gate: "session",
      path: "/admin/system-health",
      method: "GET"
    )
  end
end
