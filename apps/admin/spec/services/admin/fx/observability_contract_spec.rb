require "rails_helper"

RSpec.describe Admin::Fx::ObservabilityContract do
  it "returns an empty snapshot with expected keys" do
    snapshot = described_class.empty(range_from: "2026-04-01", range_to: "2026-04-07", days: 7)

    expect(snapshot[:range]).to include(from: "2026-04-01", to: "2026-04-07", days: 7)
    expect(snapshot[:summary]).to include(total: 0, success: 0, failed: 0, running: 0, pending: 0)
    expect(snapshot[:sources]).to eq([])
    expect(snapshot[:counts_by_source]).to eq([])
    expect(snapshot[:counts_by_source_totals]).to eq([])
    expect(snapshot[:failures_by_code]).to eq([])
    expect(snapshot[:failures_by_code_totals]).to eq([])
    expect(snapshot[:events]).to eq([])
  end
end
