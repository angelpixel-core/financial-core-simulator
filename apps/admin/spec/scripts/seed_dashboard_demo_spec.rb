require "rails_helper"

RSpec.describe "dashboard demo seed script" do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.zone.parse("2026-03-06 15:00:00")) { example.run }
  end

  it "creates 14-day coverage plus non-zero global pnl and multiple top accounts" do
    load Rails.root.join("script/seed_dashboard_demo.rb")

    metrics = Admin::DashboardMetrics.new.call

    expect(metrics[:runs_trend_14d].size).to eq(14)
    expect(metrics[:runs_trend_14d].all? { |point| point[:count].positive? }).to be(true)

    total_pnl = BigDecimal(metrics.fetch(:latest_global).fetch("totalPnLQuote").to_s)
    expect(total_pnl).not_to eq(BigDecimal("0"))

    top_account_ids = metrics.fetch(:top_accounts).map { |entry| entry.fetch(:account_id) }
    expect(top_account_ids.size).to be >= 3
    expect(top_account_ids.uniq).to eq(top_account_ids)
    expect(top_account_ids).to include("acc-1")
  end

  it "is idempotent by run_uuid" do
    load Rails.root.join("script/seed_dashboard_demo.rb")
    seeded_count = Run.count

    load Rails.root.join("script/seed_dashboard_demo.rb")

    expect(Run.count).to eq(seeded_count)
  end
end
