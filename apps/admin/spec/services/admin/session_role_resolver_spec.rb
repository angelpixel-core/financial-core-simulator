require "rails_helper"
require "bcrypt"

RSpec.describe Admin::SessionRoleResolver do
  it "resolves operator role for ops@example.com" do
    account = Account.new(email: "ops@example.com")

    expect(described_class.call(account)).to eq("operator")
  end

  it "resolves admin role for admin@example.com" do
    account = Account.new(email: "admin@example.com")

    expect(described_class.call(account)).to eq("admin")
  end

  it "falls back to viewer for unmapped accounts" do
    account = Account.new(email: "analyst@example.com")

    expect(described_class.call(account)).to eq("viewer")
  end

  it "prefers persisted account role over email mapping" do
    Admin::AccessControl::Roles::Repository.new.ensure_defaults!
    account = Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )
    Admin::AccessControl::AccountRoles::Repository.new.assign_role!(
      account_id: account.id,
      role_key: "admin",
      assigned_by_id: "seed"
    )

    expect(described_class.call(account)).to eq("admin")
  end
end
