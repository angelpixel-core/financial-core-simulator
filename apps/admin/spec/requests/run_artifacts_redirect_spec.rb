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

  it "redirects admin-like risk path to app artifact endpoint" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/admin/resources/runs/#{run.id}/risk"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/risk")
  end

  it "keeps legacy /avo risk path redirect for compatibility" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/avo/resources/runs/#{run.id}/risk"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/risk")
  end

  it "redirects admin-like positions path to app artifact endpoint" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/admin/resources/runs/#{run.id}/positions"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/positions")
  end

  it "keeps legacy /avo positions path redirect for compatibility" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/avo/resources/runs/#{run.id}/positions"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/positions")
  end

  it "redirects admin-like pnl path to app artifact endpoint" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/admin/resources/runs/#{run.id}/pnl"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/pnl")
  end

  it "keeps legacy /avo pnl path redirect for compatibility" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/avo/resources/runs/#{run.id}/pnl"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/pnl")
  end

  it "keeps admin risk redirect target stable when query params are present" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    get "/admin/resources/runs/#{run.id}/risk", params: { status: "MARGIN_CALL" }

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers["Location"]).to end_with("/runs/#{run.id}/risk")
  end
end
