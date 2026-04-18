require "rails_helper"
require "rack/test"

RSpec.describe "Admin demo dataset uploads", type: :request do
  let(:tempfile) { Tempfile.new(["demo", ".xlsx"]) }
  let(:upload) do
    Rack::Test::UploadedFile.new(
      tempfile.path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      original_filename: "demo.xlsx"
    )
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  it "creates placeholders and gaps for missing rates on upload" do
    ReportingSetting.current.update!(reporting_currency: "ARS")

    input = {
      trades: [
        {timestamp: Time.utc(2026, 3, 29, 12, 0, 0).to_i},
        {timestamp: Time.utc(2026, 3, 30, 12, 0, 0).to_i}
      ]
    }

    result = Admin::Demo::Datasets::ExcelToInputParser::Result.new(
      valid?: true,
      input: input,
      errors: []
    )

    allow(Admin::Demo::Datasets::ExcelToInputParser).to receive(:call).and_return(result)
    stub_successful_run_execution

    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "100",
      source: "manual"
    )

    post "/admin/demo-datasets", params: {file: upload}, headers: admin_session_headers

    placeholder = FxDailyRate.find_by(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS"
    )

    expect(response).to have_http_status(:found)
    expect(Run.order(:id).last.status).to eq("succeeded")
    expect(placeholder).to be_present
    expect(placeholder.source).to eq("placeholder")
    expect(FxRateGap.where(status: "open").count).to eq(1)
  end

  it "persists run and valid trades when parser returns row errors" do
    input = {
      trades: [
        {
          tradeId: "trade-ok",
          accountId: "account-ok",
          marketId: "ETH-USD",
          timestamp: Time.utc(2026, 3, 29, 12, 0, 0).to_i,
          seq: 1,
          side: "BUY",
          quantityBase: "1.0",
          priceQuotePerBase: "120.0"
        }
      ],
      feeModel: {enabled: false}
    }

    result = Admin::Demo::Datasets::ExcelToInputParser::Result.new(
      valid?: false,
      input: input,
      errors: [
        {
          line: 4,
          code: "INVALID_SIDE",
          source: "dataset_upload",
          row_index: 2,
          trade_id: "trade-bad",
          account_id: "account-bad",
          market_id: "ETH-USD"
        }
      ]
    )

    allow(Admin::Demo::Datasets::ExcelToInputParser).to receive(:call).and_return(result)
    stub_successful_run_execution

    post "/admin/demo-datasets", params: {file: upload}, headers: admin_session_headers

    run = Run.order(:id).last
    upload_record = DemoDatasetUpload.order(:id).last

    expect(response).to have_http_status(:found)
    expect(run).to be_present
    expect(run.status).to eq("failed")
    expect(run.reliable).to eq(false)
    expect(run.error_code).to eq(Runs::ErrorCodeMapper::VALIDATION_GENERAL)
    expect(upload_record).to be_present
    expect(upload_record.status).to eq("invalid")
    expect(upload_record.run_id).to eq(run.id)
    expect(upload_record.validation_errors).to include(hash_including("code" => "INVALID_SIDE"))
    expect(run.run_validation_errors.where(code: "INVALID_SIDE", trade_id: "trade-bad")).to exist
  end

  it "rejects duplicate uploads by full filename" do
    DemoDatasetUpload.create!(
      status: :valid,
      original_filename: "demo.xlsx"
    )

    post "/admin/demo-datasets", params: {file: upload}, headers: admin_session_headers

    expect(response).to have_http_status(:found)
    expect(flash[:alert]).to include("already processed")
  end

  it "resets runs and FX history data" do
    Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0", "trades" => []})
    DemoDatasetUpload.create!(status: :valid, original_filename: "demo.xlsx")
    FxDailyRate.create!(operational_date: Date.new(2026, 3, 30), base_currency: "USD", quote_currency: "ARS", rate: "100",
      source: "manual")
    FxRateGap.create!(operational_date: Date.new(2026, 3, 30), base_currency: "USD", quote_currency: "ARS",
      status: "open")
    FxRateUpload.create!(status: "success", original_filename: "fx.xlsx")
    source = FxRateSource.find_or_create_by!(code: "ext", source_type: "api", version: "1") do |record|
      record.name = "Ext API"
      record.active = true
      record.config = {endpoint: "https://example.test/rates"}
    end
    ingestion = FxRateIngestion.create!(source: source, correlation_id: "corr-1", status: "success")
    FxRateEvent.create!(event_type: "fx.rate.ingestion.completed", metadata: {correlation_id: "corr-1"}, data: {})
    FxRateLineage.create!(
      ingestion: ingestion,
      source: source,
      correlation_id: "corr-1",
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      status: "valid"
    )

    post "/admin/demo-datasets/reset", headers: admin_session_headers

    expect(response).to have_http_status(:found)
    expect(Run.count).to eq(0)
    expect(DemoDatasetUpload.count).to eq(0)
    expect(FxDailyRate.count).to eq(0)
    expect(FxRateGap.count).to eq(0)
    expect(FxRateUpload.count).to eq(0)
    expect(FxRateIngestion.count).to eq(0)
    expect(FxRateEvent.count).to eq(0)
    expect(FxRateLineage.count).to eq(0)
  end

  def admin_session_headers
    {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}
  end

  def stub_successful_run_execution
    execute_service = instance_double(Runs::Execute)
    verify_service = instance_double(Runs::VerifyInputHash)

    allow(Runs::Execute).to receive(:new).and_return(execute_service)
    allow(execute_service).to receive(:call) do |run, **_opts|
      run.update!(status: :succeeded, input_hash: "abc123", run_uuid: "run-1")
      run
    end

    allow(Runs::VerifyInputHash).to receive(:new).and_return(verify_service)
    allow(verify_service).to receive(:call)
  end
end
