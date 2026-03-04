require "rails_helper"

RSpec.describe "Admin ingestion validation errors", type: :request do
  it "renders ingestion validation errors panel on overview" do
    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingestion validation errors")
    expect(response.body).to include("/admin/overview/ingestion-validation-errors")
  end

  it "renders ingestion validation errors fragment for xhr polling" do
    get "/admin/overview/ingestion-validation-errors", headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ingestion validation errors")
  end
end
