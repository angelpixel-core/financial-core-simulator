require "rails_helper"

RSpec.describe Admin::Dashboard::IngestionValidationErrorsResponseSerializer do
  it "serializes ingestion validation errors with stable API keys" do
    errors = [
      {
        source: "source.venue.external",
        field: "riskModel",
        message: "risk invalid",
        occurredAt: "2026-03-05T12:00:00Z",
        correlationId: "corr-001"
      }
    ]

    payload = described_class.new.serialize(errors: errors)

    expect(payload).to eq(
      "contractVersion" => "v1",
      "errors" => [
        {
          "source" => "source.venue.external",
          "field" => "riskModel",
          "message" => "risk invalid",
          "occurredAt" => "2026-03-05T12:00:00Z",
          "correlationId" => "corr-001"
        }
      ]
    )
  end
end
