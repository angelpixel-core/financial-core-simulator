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

  def admin_session_headers
    {"X-Admin-User" => "ops", "X-Admin-Role" => "operator"}
  end
end
