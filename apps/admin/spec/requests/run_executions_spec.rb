require "rails_helper"

RSpec.describe "Run executions", type: :request do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "executes run synchronously by default" do
    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    service = instance_double(Runs::Execute)
    allow(Runs::Execute).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run, fee_enabled: true, explain: true, verbose: false)

    post "/runs/#{run.id}/execute", as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed.fetch("status")).to eq("executed")
    expect(parsed.fetch("runId")).to eq(run.id)
    expect(parsed.fetch("runStatus")).to eq("queued")
  end

  it "enqueues run execution when async=1" do
    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    post "/runs/#{run.id}/execute", params: { async: 1 }, as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed.fetch("status")).to eq("enqueued")
    expect(parsed.fetch("runId")).to eq(run.id)
    expect(parsed.fetch("runStatus")).to eq("queued")
    expect(RunExecutionJob).to have_been_enqueued.with(run.id, fee_enabled: true, explain: true, verbose: false)
  end

  it "returns forbidden when ADMIN_UI_TOKEN is set and missing" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    post "/runs/#{run.id}/execute", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "allows execution when ADMIN_UI_TOKEN is provided" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    service = instance_double(Runs::Execute)
    allow(Runs::Execute).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run, fee_enabled: true, explain: true, verbose: false)

    post "/runs/#{run.id}/execute", headers: { "X-Admin-Token" => "ui-secret" }, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "allows execution when ADMIN_UI_TOKEN is provided as bearer token" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    service = instance_double(Runs::Execute)
    allow(Runs::Execute).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run, fee_enabled: true, explain: true, verbose: false)

    post "/runs/#{run.id}/execute", headers: { "Authorization" => "Bearer ui-secret" }, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "allows execution via operator role when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    service = instance_double(Runs::Execute)
    allow(Runs::Execute).to receive(:new).and_return(service)
    expect(service).to receive(:call).with(run, fee_enabled: true, explain: true, verbose: false)

    post "/runs/#{run.id}/execute", headers: { "X-Admin-User" => "ops", "X-Admin-Role" => "operator" }, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "forbids execution via viewer role when operator role is required" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    run = Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })

    post "/runs/#{run.id}/execute", headers: { "X-Admin-User" => "viewer", "X-Admin-Role" => "viewer" }, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
