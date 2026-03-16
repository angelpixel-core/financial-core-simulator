# frozen_string_literal: true

require_relative "../../lib/fcs"
require "json"

RSpec.describe FCS::Ingestion::SourceEventNormalizationPipeline do
  subject(:pipeline) { described_class.new }

  def fixture(name)
    path = File.join(__dir__, "..", "fixtures", "source_events", name)
    JSON.parse(File.read(path))
  end

  it "routes agente source events through AgenteIntentMapper" do
    source_event = fixture("valid_agente_intent.json")

    normalized = pipeline.normalize!(source_event)

    expect(normalized).to include(
      "eventType" => "AGENTE_INTENT_NORMALIZED",
      "source" => "agente.hft.alpha"
    )
  end

  it "routes venue source events through VenueExecutionMapper" do
    source_event = fixture("valid_venue_execution.json")

    normalized = pipeline.normalize!(source_event)

    expect(normalized).to include(
      "eventType" => "VENUE_EXECUTION_NORMALIZED",
      "source" => "venue.internal.matcher"
    )
  end

  it "routes faucet source events through FaucetIssuanceMapper" do
    source_event = fixture("valid_faucet_issuance.json")

    normalized = pipeline.normalize!(source_event)

    expect(normalized).to include(
      "eventType" => "FAUCET_ISSUANCE_NORMALIZED",
      "source" => "faucet.erc20.ang"
    )
  end

  it "normalizes a batch through the same pipeline entrypoint" do
    events = [
      fixture("valid_agente_intent.json"),
      fixture("valid_venue_execution.json"),
      fixture("valid_faucet_issuance.json")
    ]

    normalized = pipeline.normalize_batch!(events)

    expect(normalized.map { |event| event.fetch("eventType") }).to eq(%w[
                                                                        AGENTE_INTENT_NORMALIZED
                                                                        VENUE_EXECUTION_NORMALIZED
                                                                        FAUCET_ISSUANCE_NORMALIZED
                                                                      ])
  end

  it "rejects unsupported source in pipeline" do
    source_event = fixture("valid_venue_execution.json")
    source_event["source"] = "robot.unknown"

    expect { pipeline.normalize!(source_event) }
      .to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(error.details).to include(field: "sourceEvent.source")
      }
  end
end
