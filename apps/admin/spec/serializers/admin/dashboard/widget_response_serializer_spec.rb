require "rails_helper"

RSpec.describe Admin::Dashboard::WidgetResponseSerializer do
  it "serializes top accounts through compatibility guard" do
    guard = instance_double("Admin::Dashboard::CompatibilityGuard")
    serializer = described_class.new(compatibility_guard: guard)

    expect(guard).to receive(:widget_payload).with(
      payload: { "topAccounts" => [] },
      required_widget_keys: [ "topAccounts" ]
    ).and_return("contractVersion" => "v1", "topAccounts" => [])

    result = serializer.top_accounts(metrics: { top_accounts: [] })

    expect(result).to eq("contractVersion" => "v1", "topAccounts" => [])
  end

  it "serializes trend through compatibility guard" do
    guard = instance_double("Admin::Dashboard::CompatibilityGuard")
    serializer = described_class.new(compatibility_guard: guard)

    expect(guard).to receive(:widget_payload).with(
      payload: { "runsTrend14d" => [] },
      required_widget_keys: [ "runsTrend14d" ]
    ).and_return("contractVersion" => "v1", "runsTrend14d" => [])

    result = serializer.trend(metrics: { runs_trend_14d: [] })

    expect(result).to eq("contractVersion" => "v1", "runsTrend14d" => [])
  end

  it "serializes latest run with additive empty object when metric is nil" do
    guard = instance_double("Admin::Dashboard::CompatibilityGuard")
    serializer = described_class.new(compatibility_guard: guard)

    expect(guard).to receive(:widget_payload).with(
      payload: { "latestRun" => {} },
      required_widget_keys: [ "latestRun" ]
    ).and_return("contractVersion" => "v1", "latestRun" => {})

    result = serializer.latest_run(metrics: { latest_run: nil })

    expect(result).to eq("contractVersion" => "v1", "latestRun" => {})
  end
end
