require "rails_helper"

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
end
