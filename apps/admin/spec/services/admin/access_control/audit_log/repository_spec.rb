require "rails_helper"
require "bcrypt"

RSpec.describe Admin::AccessControl::AuditLog::Repository do
  subject(:repository) { described_class.new(event_bus: event_bus) }

  let(:event_bus) { instance_double(Admin::Events::BusAdapter, publish: true) }

  it "records audit entries and emits event" do
    account = Account.create!(
      email: "audit-user@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    log = repository.record!(
      action: "authorization.session",
      outcome: "allow",
      account: account,
      role: "operator",
      required_role: "viewer",
      context: {path: "/admin/overview"}
    )

    expect(log).to be_persisted
    expect(log.outcome).to eq("allow")
    expect(log.context).to include("path" => "/admin/overview")
    expect(event_bus).to have_received(:publish).with(
      "access_control.authorization.checked",
      hash_including(action: "authorization.session", outcome: "allow", account_id: account.id)
    )
  end
end
