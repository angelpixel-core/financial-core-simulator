require "rails_helper"

RSpec.describe Admin::Demo::Access do
  around do |example|
    previous_enabled = ENV["DEMO_LOCK_ENABLED"]
    previous_ttl = ENV["DEMO_LOCK_TTL_SECONDS"]
    example.run
  ensure
    ENV["DEMO_LOCK_ENABLED"] = previous_enabled
    ENV["DEMO_LOCK_TTL_SECONDS"] = previous_ttl
  end

  it "does not block when feature flag is disabled" do
    ENV["DEMO_LOCK_ENABLED"] = "0"

    result = described_class.acquire(account_id: "1", account_email: "ops@example.com")

    expect(result.granted).to eq(true)
    expect(described_class.current_user).to be_nil
  end

  it "grants lock to first user and blocks another until ttl expires" do
    ENV["DEMO_LOCK_ENABLED"] = "1"
    ENV["DEMO_LOCK_TTL_SECONDS"] = "900"
    now = Time.zone.parse("2026-04-21 12:00:00 UTC")

    first = described_class.acquire(account_id: "1", account_email: "one@example.com", now: now)
    second = described_class.acquire(account_id: "2", account_email: "two@example.com", now: now + 5.minutes)

    expect(first.granted).to eq(true)
    expect(second.granted).to eq(false)
    expect(second.owner).to include(account_id: "1", email: "one@example.com")

    recovered = described_class.acquire(account_id: "2", account_email: "two@example.com", now: now + 16.minutes)
    expect(recovered.granted).to eq(true)
    expect(described_class.current_user(now: now + 16.minutes)).to include(account_id: "2")
  end

  it "releases lock on demand" do
    ENV["DEMO_LOCK_ENABLED"] = "1"

    described_class.acquire(account_id: "1", account_email: "one@example.com")
    expect(described_class.current_user).to include(account_id: "1")

    released = described_class.release(account_id: "1")

    expect(released).to eq(true)
    expect(described_class.current_user).to be_nil
  end
end
