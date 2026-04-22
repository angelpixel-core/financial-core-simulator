require "rails_helper"

RSpec.describe "Admin FX rate uploads", type: :request do
  include ActiveJob::TestHelper

  it "creates upload and enqueues processing job" do
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs

    uploaded_file = Tempfile.new(["fx-rates", ".xlsx"])
    uploaded_file.binmode
    uploaded_file.write("test")
    uploaded_file.rewind

    file = Rack::Test::UploadedFile.new(
      uploaded_file.path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: "fx_rates_template.xlsx"
    )

    expect do
      post "/admin/fx/rate_uploads", params: {file: file}, headers: operator_headers
    end.to have_enqueued_job(Admin::Fx::RateUploadJob)

    upload = FxRateUpload.order(created_at: :desc).first
    expect(upload).to be_present
    expect(upload.status).to eq("processing")
    expect(upload.original_filename).to eq("fx_rates_template.xlsx")
    expect(upload.file_path).to be_present
    expect(response).to have_http_status(:found)
  ensure
    uploaded_file&.close
    uploaded_file&.unlink
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
  end

  it "returns preview error when file is missing" do
    post "/admin/fx/rate_uploads/preview", headers: operator_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("fx-rate-upload-preview")
  end

  it "returns json error payload when create file is missing" do
    post "/admin/fx/rate_uploads", headers: operator_headers.merge("ACCEPT" => "application/json")

    expect(response).to have_http_status(:unprocessable_content)
    payload = JSON.parse(response.body)
    expect(payload["code"]).to eq("MISSING_FILE")
    expect(payload["state"]).to eq("invalid")
  end

  it "returns json preview payload when file is missing" do
    post "/admin/fx/rate_uploads/preview", headers: operator_headers.merge("ACCEPT" => "application/json")

    expect(response).to have_http_status(:unprocessable_content)
    payload = JSON.parse(response.body)
    expect(payload["state"]).to eq("error")
    expect(payload["errors"]).to be_an(Array)
    expect(payload["errors"].first["code"]).to eq("MISSING_FILE")
  end

  it "rejects create when file exceeds configured size" do
    uploaded_file = Tempfile.new(["fx-rates", ".xlsx"])
    uploaded_file.binmode
    uploaded_file.write("test")
    uploaded_file.rewind

    file = Rack::Test::UploadedFile.new(
      uploaded_file.path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: "fx_rates_template.xlsx"
    )

    allow(Admin::UploadLimits).to receive(:exceeds_file_size?).and_return(true)
    allow(Admin::UploadLimits).to receive(:max_upload_file_size_mb).and_return(10)

    expect do
      post "/admin/fx/rate_uploads", params: {file: file}, headers: operator_headers
    end.not_to have_enqueued_job(Admin::Fx::RateUploadJob)

    expect(response).to have_http_status(:found)
    expect(flash[:alert]).to include("10MB")
    expect(FxRateUpload.count).to eq(0)
  ensure
    uploaded_file&.close
    uploaded_file&.unlink
  end

  it "rejects preview when file exceeds configured size" do
    uploaded_file = Tempfile.new(["fx-rates", ".xlsx"])
    uploaded_file.binmode
    uploaded_file.write("test")
    uploaded_file.rewind

    file = Rack::Test::UploadedFile.new(
      uploaded_file.path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: "fx_rates_template.xlsx"
    )

    allow(Admin::UploadLimits).to receive(:exceeds_file_size?).and_return(true)
    allow(Admin::UploadLimits).to receive(:max_upload_file_size_mb).and_return(10)

    post "/admin/fx/rate_uploads/preview", params: {file: file}, headers: operator_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Preview found issues")
    expect(response.body).to include("10MB")
  ensure
    uploaded_file&.close
    uploaded_file&.unlink
  end

  it "clears only fx daily rates" do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "1000",
      source: "manual"
    )
    FxRateGap.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      status: "open"
    )

    post "/admin/fx/rate_uploads/clear", headers: operator_headers

    expect(response).to have_http_status(:found)
    expect(FxDailyRate.count).to eq(0)
    expect(FxRateGap.count).to eq(1)
  end

  def operator_headers
    {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}
  end
end
