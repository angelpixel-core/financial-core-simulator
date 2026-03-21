require "rails_helper"

RSpec.describe Admin::Validation::IngestionValidationErrorMapper do
  it "maps validation failed run into stable ingestion error shape" do
    run = Run.create!(
      status: :failed,
      run_uuid: "run-uuid-001",
      error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
      error_message: "risk invalid",
      input_json: {
        "correlationId" => "corr-001",
        "timeline" => {
          "events" => [
            { "source" => "source.venue.external" }
          ]
        }
      }
    )

    mapped = described_class.new.map(run: run)

    expect(mapped).to include(
      source: "source.venue.external",
      field: "riskModel",
      message: "risk invalid",
      correlation_id: "corr-001"
    )
    expect(mapped[:occurred_at]).to be_a(String)
  end

  it "falls back to run_uuid when correlationId is missing" do
    run = Run.create!(
      status: :failed,
      run_uuid: "run-uuid-fallback",
      error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
      error_message: "accounting invalid",
      input_json: {
        "timeline" => {
          "events" => [
            { "source" => "agente.hft.alpha" }
          ]
        }
      }
    )

    mapped = described_class.new.map(run: run)

    expect(mapped).to include(
      source: "agente.hft.alpha",
      field: "accountingModel.method",
      correlation_id: "run-uuid-fallback"
    )
  end
end
