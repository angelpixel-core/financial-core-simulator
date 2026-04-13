require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::EventEmitter do
  let(:source) do
    FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0"}
    )
  end

  it "persists events and returns a success result" do
    emitter = described_class.new

    result = emitter.emit(
      event_type: "fx_rate.ingested",
      data: {"count" => 1},
      metadata: {"source_id" => source.id, "correlation_id" => "abc"}
    )

    expect(result).to be_success
    expect(FxRateEvent.last.event_type).to eq("fx_rate.ingested")
  end

  it "returns failure for invalid event types" do
    emitter = described_class.new

    result = emitter.emit(event_type: "fx_rate.unknown")

    expect(result).to be_failure
    expect(result.error_code).to eq("event_invalid")
  end

  it "emits ingestion events with standard metadata" do
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "pending",
      correlation_id: "corr-1"
    )
    emitter = described_class.new

    result = emitter.emit_ingestion(
      event_type: "fx_rate.ingested",
      ingestion: ingestion,
      source: source,
      data: {record_count: 2}
    )

    expect(result).to be_success
    event = FxRateEvent.last
    expect(event.data["source_id"]).to eq(source.id)
    expect(event.data["source_code"]).to eq("BCRA")
    expect(event.metadata["ingestion_id"]).to eq(ingestion.id)
    expect(event.metadata["correlation_id"]).to eq("corr-1")
  end
end
