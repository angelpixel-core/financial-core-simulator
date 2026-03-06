require "rails_helper"

RSpec.describe "Admin ingestion validation errors", type: :request do
  it "renders ingestion validation errors panel on overview" do
    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingestion validation errors")
    expect(response.body).to include("/admin/overview/ingestion-validation-errors")
    expect(response.body).to include("data-turbo-frame=\"overview-ingestion-validation-errors-panel\"")
    expect(response.body).to include("submit->ingestion-filters#syncPollUrl")
    expect(response.body).to include("click->ingestion-filters#reset")
    expect(response.body).to include("input->ingestion-filters#scheduleSubmit")
    expect(response.body).to include("blur->ingestion-filters#submitNow")
  end

  it "keeps selected filters in panel polling url on overview" do
    get "/admin/overview", params: { source: "source.venue.external", field: "riskModel" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("data-poll-url-value=\"/admin/overview/ingestion-validation-errors?field=riskModel&amp;source=source.venue.external\"")
  end

  it "renders ingestion validation errors fragment for xhr polling" do
    get "/admin/overview/ingestion-validation-errors", headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingestion validation errors")
  end

  it "renders turbo-frame response for hotwire filter submit" do
    get "/admin/overview/ingestion-validation-errors", headers: { "Turbo-Frame" => "overview-ingestion-validation-errors-panel" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<turbo-frame id=\"overview-ingestion-validation-errors-panel\"")
    expect(response.body).to include("Ingestion validation errors")
  end

  it "filters by source in the ingestion validation errors panel" do
    create_validation_failed_run(source: "source.agent.internal", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")
    create_validation_failed_run(source: "source.venue.external", error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING, message: "accounting invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { source: "source.venue.external" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("source.venue.external")
    expect(response.body).not_to include("source.agent.internal")
  end

  it "filters by partial source match in the ingestion validation errors panel" do
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")
    create_validation_failed_run(source: "source.venue.external", error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING, message: "accounting invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { source: "agen" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("agente.hft.alpha")
    expect(response.body).not_to include("source.venue.external")
  end

  it "filters by source alias match in the ingestion validation errors panel" do
    create_validation_failed_run(source: "source.venue.external", error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING, message: "accounting invalid")
    create_validation_failed_run(source: "source.agent.internal", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { source: "src" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("source.venue.external")
    expect(response.body).to include("source.agent.internal")
  end

  it "filters by field in the ingestion validation errors panel" do
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING, message: "accounting invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { field: "riskModel" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("riskModel")
    expect(response.body).not_to include("accountingModel.method")
  end

  it "filters by partial case-insensitive field in the ingestion validation errors panel" do
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING, message: "accounting invalid")
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_TRADE_DECIMAL, message: "trade decimal invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { field: "Model" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("riskModel")
    expect(response.body).to include("accountingModel.method")
    expect(response.body).not_to include("trade.decimal")
  end

  it "renders empty-state for non-matching source+field filter" do
    create_validation_failed_run(source: "agente.hft.alpha", error_code: Runs::ErrorCodeMapper::VALIDATION_RISK, message: "risk invalid")

    get "/admin/overview/ingestion-validation-errors",
        params: { source: "faucet.erc20.ang", field: "accounts.collateralQuote" },
        headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No ingestion validation errors.")
  end

  def create_validation_failed_run(source:, error_code:, message:)
    Run.create!(
      status: :failed,
      error_code: error_code,
      error_message: message,
      input_json: {
        "correlationId" => "corr-#{SecureRandom.hex(4)}",
        "timeline" => {
          "events" => [
            { "source" => source }
          ]
        }
      }
    )
  end
end
