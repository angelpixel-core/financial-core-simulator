require "rails_helper"

RSpec.describe Admin::Demo::AbuseProtection do
  let(:request) { ActionDispatch::TestRequest.create }

  around do |example|
    keys = %w[
      DEMO_RATE_LIMIT_LOGIN_PER_MINUTE
      DEMO_RATE_LIMIT_UPLOAD_PER_HOUR
      DEMO_RATE_LIMIT_PREVIEW_PER_HOUR
      DEMO_RATE_LIMIT_EXECUTION_PER_HOUR
      DEMO_QUOTA_UPLOADS_PER_HOUR
      DEMO_QUOTA_UPLOAD_VOLUME_MB_PER_DAY
    ]
    previous = keys.to_h { |key| [key, ENV[key]] }
    DemoUsageEvent.delete_all
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "rejects login when rate limit is exceeded" do
    ENV["DEMO_RATE_LIMIT_LOGIN_PER_MINUTE"] = "1"

    described_class.enforce_login!(request: request)

    expect do
      described_class.enforce_login!(request: request)
    end.to raise_error(Admin::Demo::AbuseProtection::LimitExceeded, /Too many login attempts/i)

    expect(DemoUsageEvent.for_action("login").rejected.count).to eq(1)
  end

  it "rejects upload when hourly quota is exceeded" do
    ENV["DEMO_RATE_LIMIT_UPLOAD_PER_HOUR"] = "20"
    ENV["DEMO_QUOTA_UPLOADS_PER_HOUR"] = "1"

    described_class.enforce_upload!(request: request, account: nil, file_size_bytes: 100)

    expect do
      described_class.enforce_upload!(request: request, account: nil, file_size_bytes: 100)
    end.to raise_error(Admin::Demo::AbuseProtection::LimitExceeded, /quota per hour/i)

    expect(DemoUsageEvent.for_action("upload").allowed.count).to eq(1)
    expect(DemoUsageEvent.for_action("upload").rejected.count).to eq(1)
  end

  it "computes usage summary for last 24h" do
    DemoUsageEvent.create!(action: "upload", status: "allowed", actor_id: "u1", created_at: 1.hour.ago)
    DemoUsageEvent.create!(action: "preview", status: "allowed", actor_id: "u1", created_at: 2.hours.ago)
    DemoUsageEvent.create!(action: "execution", status: "rejected", actor_id: "u1", created_at: 3.hours.ago)

    summary = described_class.summary

    expect(summary).to include(requests_24h: 3, uploads_24h: 1, rejections_24h: 1)
  end
end
