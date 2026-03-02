require "rails_helper"

RSpec.describe "Run artifacts redirect", type: :request do
  it "redirects admin-like result path to app artifact endpoint" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/admin/resources/runs/#{run.id}/result"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/result")
  end

  it "keeps legacy /avo result path redirect for compatibility" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/avo/resources/runs/#{run.id}/result"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/result")
  end
end
