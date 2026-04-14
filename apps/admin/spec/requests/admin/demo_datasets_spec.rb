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

    result = Admin::DemoDataset::ExcelToInputParser::Result.new(
      valid?: true,
      input: input,
      errors: []
    )

    allow(Admin::DemoDataset::ExcelToInputParser).to receive(:call).and_return(result)
    allow(Runs::Execute).to receive_message_chain(:new, :call)
    allow(Runs::VerifyInputHash).to receive_message_chain(:new, :call)

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

    result = Admin::DemoDataset::ExcelToInputParser::Result.new(
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

    allow(Admin::DemoDataset::ExcelToInputParser).to receive(:call).and_return(result)
    allow(Runs::Execute).to receive_message_chain(:new, :call)
    allow(Runs::VerifyInputHash).to receive_message_chain(:new, :call)

    post "/admin/demo-datasets", params: {file: upload}, headers: admin_session_headers

    run = Run.order(:id).last
    upload_record = DemoDatasetUpload.order(:id).last

    expect(response).to have_http_status(:found)
    expect(run).to be_present
    expect(run.reliable).to eq(false)
    expect(upload_record).to be_present
    expect(upload_record.status).to eq("invalid")
    expect(upload_record.run_id).to eq(run.id)
    expect(upload_record.validation_errors).to include(hash_including("code" => "INVALID_SIDE"))
    expect(run.run_validation_errors.where(code: "INVALID_SIDE", trade_id: "trade-bad")).to exist
  end

  def admin_session_headers
    {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}
  end
end
