require "rails_helper"
require "bcrypt"

RSpec.describe "Admin Avo shell parity", type: :request do
  it "denies operator session access to avo html resources" do
    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/resources/runs"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "allows admin session access to avo html resources" do
    Account.create!(
      email: "admin@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "admin@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/resources/runs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("admin@example.com")
    expect(response.body).to include("/admin/logout")
  end

  it "keeps unauthenticated avo resource access protected" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/resources/runs"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end
end
