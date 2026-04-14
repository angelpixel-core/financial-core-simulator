require "rails_helper"

RSpec.describe Admin::Fx::ObservabilitySnapshot do
  let(:source) do
    FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0",
        "currency_code" => "USD"
      }
    )
  end
  let(:source_two) do
    FxRateSource.create!(
      name: "Alternate Source",
      code: "ALT",
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://example.com",
        "currency_code" => "USD"
      }
    )
  end

  it "builds summary counts and events" do
    FxRateIngestion.create!(source: source, status: "success", correlation_id: "c1")
    FxRateIngestion.create!(source: source, status: "failed", correlation_id: "c2", error_code: "http_error")
    FxRateEvent.create!(
      event_type: "fx_rate.fetch_failed",
      data: {"error_code" => "http_error", "severity" => "error", "source_id" => source.id},
      metadata: {"ingestion_id" => 1, "source_id" => source.id}
    )

    snapshot = described_class.call(source_id: source.id, days: 7)

    expect(snapshot[:summary][:total]).to eq(2)
    expect(snapshot[:summary][:failed]).to eq(1)
    expect(snapshot[:failures_by_code].first[:error_code]).to eq("http_error")
    expect(snapshot[:failures_by_code].first[:time_bucket]).to be_present
    expect(snapshot[:events].first[:event_type]).to eq("fx_rate.fetch_failed")
    expect(snapshot[:events].first[:time_bucket]).to be_present
  end

  it "aggregates per-source counts and totals" do
    travel_to(Time.zone.parse("2026-04-10 09:00:00")) do
      FxRateIngestion.create!(source: source, status: "success", created_at: Time.zone.parse("2026-04-09 10:00:00"))
      FxRateIngestion.create!(source: source, status: "failed", error_code: "http_error",
        created_at: Time.zone.parse("2026-04-09 11:00:00"))
      FxRateIngestion.create!(source: source, status: "success", created_at: Time.zone.parse("2026-04-08 10:00:00"))
      FxRateIngestion.create!(source: source_two, status: "running",
        created_at: Time.zone.parse("2026-04-09 12:00:00"))
      FxRateIngestion.create!(source: source_two, status: "pending",
        created_at: Time.zone.parse("2026-04-08 12:00:00"))

      snapshot = described_class.call(days: 7)

      bucketed = snapshot[:counts_by_source].select { |entry| entry[:source_id] == source.id }
      expect(bucketed.map { |entry| entry[:time_bucket] }).to include("2026-04-09", "2026-04-08")

      totals = snapshot[:counts_by_source_totals].find { |entry| entry[:source_id] == source.id }
      expect(totals).to include(success: 2, failed: 1, running: 0, pending: 0)
    end
  end

  it "aggregates failures by code with totals" do
    travel_to(Time.zone.parse("2026-04-10 09:00:00")) do
      FxRateIngestion.create!(source: source, status: "failed", error_code: "http_error",
        created_at: Time.zone.parse("2026-04-09 10:00:00"))
      FxRateIngestion.create!(source: source, status: "failed", error_code: "http_error",
        created_at: Time.zone.parse("2026-04-08 10:00:00"))
      FxRateIngestion.create!(source: source, status: "failed", error_code: "mapping_failed",
        created_at: Time.zone.parse("2026-04-09 12:00:00"))

      snapshot = described_class.call(days: 7)

      bucketed = snapshot[:failures_by_code].select { |entry| entry[:error_code] == "http_error" }
      expect(bucketed.map { |entry| entry[:time_bucket] }).to contain_exactly("2026-04-09", "2026-04-08")

      totals = snapshot[:failures_by_code_totals]
      http_total = totals.find { |entry| entry[:error_code] == "http_error" }
      mapping_total = totals.find { |entry| entry[:error_code] == "mapping_failed" }
      expect(http_total[:count]).to eq(2)
      expect(mapping_total[:count]).to eq(1)
    end
  end

  it "limits events to 20 and filters by source" do
    travel_to(Time.zone.parse("2026-04-10 09:00:00")) do
      22.times do |index|
        FxRateEvent.create!(
          event_type: "fx_rate.fetch_failed",
          data: {"error_code" => "http_error", "severity" => "error", "source_id" => source.id},
          metadata: {"source_id" => source.id},
          created_at: Time.zone.parse("2026-04-09 10:00:00") + index.minutes
        )
      end

      3.times do |index|
        FxRateEvent.create!(
          event_type: "fx_rate.fetch_failed",
          data: {"error_code" => "mapping_failed", "severity" => "warning", "source_id" => source_two.id},
          metadata: {"source_id" => source_two.id},
          created_at: Time.zone.parse("2026-04-09 12:00:00") + index.minutes
        )
      end

      snapshot = described_class.call(source_id: source.id, days: 7)

      expect(snapshot[:events].length).to eq(20)
      expect(snapshot[:events].all? { |event| event[:source_id] == source.id }).to eq(true)

      event_times = snapshot[:events].map { |event| Time.zone.parse(event[:created_at]) }
      expect(event_times).to eq(event_times.sort.reverse)
    end
  end
end
