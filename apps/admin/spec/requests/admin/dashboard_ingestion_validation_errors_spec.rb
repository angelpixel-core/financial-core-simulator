require "rails_helper"

RSpec.describe "Dashboard ingestion validation errors", type: :request do
  it "returns stable payload keys for validation errors" do
    Run.create!(
      status: :failed,
      error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
      error_message: "risk config invalid",
      input_json: {
        "correlationId" => "corr-001",
        "timeline" => {
          "events" => [
            { "source" => "agente.hft.alpha" }
          ]
        }
      }
    )

    get "/dashboard/ingestion-validation-errors", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed).to include("contractVersion", "errors")
    expect(parsed.fetch("contractVersion")).to eq("v1")
    expect(parsed["errors"]).to be_a(Array)
    expect(parsed["errors"]).not_to be_empty
    expect(parsed["errors"].first).to include("source", "field", "message", "occurred_at", "correlation_id")
  end

  it "returns empty list when no validation failures exist" do
    Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" })

    get "/dashboard/ingestion-validation-errors", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed.fetch("errors")).to eq([])
  end

  it "returns forbidden when ADMIN_UI_TOKEN is configured and token is missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/dashboard/ingestion-validation-errors", as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
