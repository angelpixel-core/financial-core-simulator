require "rails_helper"

RSpec.describe Admin::Fx::ObservabilityExporter do
  it "returns normalized metrics and events" do
    snapshot = {
      range: {from: "2026-04-01", to: "2026-04-07", days: 7},
      counts_by_source: [
        {
          source_id: 10,
          source_code: "BCRA",
          source_name: "Banco Central",
          success: 2,
          failed: 1,
          running: 0,
          pending: 0
        }
      ],
      failures_by_code: [
        {error_code: "http_error", severity: "error", count: 1}
      ],
      events: [{event_type: "fx_rate.fetch_failed"}]
    }

    result = described_class.call(snapshot: snapshot)

    metric_names = result[:metrics].map { |metric| metric[:name] }
    expect(metric_names).to include("fx_ingestion_success_total", "fx_ingestion_failed_total",
      "fx_ingestion_failure_total")
    expect(result[:events].length).to eq(1)
  end
end
