require "rails_helper"

RSpec.describe Admin::Demo::Sandbox::Reset do
  describe "#call" do
    it "removes only demo sandbox data and updates reset state" do
      demo_run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0", "trades" => []})
      demo_upload = DemoDatasetUpload.create!(status: :valid, run_id: demo_run.id, original_filename: "demo.xlsx")

      non_demo_run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0", "trades" => []})

      FxRateGap.create!(
        operational_date: Date.new(2026, 3, 30),
        base_currency: "USD",
        quote_currency: "ARS",
        status: "open",
        source_run_id: demo_run.id,
        source_upload_id: demo_upload.id,
        created_context: {"source" => "upload"}
      )
      FxRateGap.create!(
        operational_date: Date.new(2026, 3, 31),
        base_currency: "USD",
        quote_currency: "ARS",
        status: "open"
      )

      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 30),
        base_currency: "USD",
        quote_currency: "ARS",
        rate: nil,
        source: "placeholder",
        source_run_id: demo_run.id,
        source_upload_id: demo_upload.id,
        created_context: {"source" => "upload"}
      )

      demo_fx_upload_file = Tempfile.new(["fx-demo", ".xlsx"])
      demo_fx_upload_file.write("test")
      demo_fx_upload_file.flush

      demo_fx_upload = FxRateUpload.create!(
        status: "success",
        original_filename: "fx_demo.xlsx",
        created_context: {"source" => "fx_history_upload"},
        file_path: demo_fx_upload_file.path
      )
      FxDailyRate.create!(
        operational_date: Date.new(2026, 3, 29),
        base_currency: "EUR",
        quote_currency: "ARS",
        rate: "2000",
        source: "upload",
        source_upload_id: demo_fx_upload.id,
        created_context: {"source" => "fx_history_upload"}
      )

      FxRateUpload.create!(
        status: "success",
        original_filename: "fx_non_demo.xlsx",
        created_context: {"source" => "non_demo_upload"}
      )
      FxDailyRate.create!(
        operational_date: Date.new(2026, 4, 1),
        base_currency: "BTC",
        quote_currency: "USD",
        rate: "50000",
        source: "manual"
      )

      result = described_class.new.call(trigger: "spec")

      expect(result).to include(
        "runs" => 1,
        "demo_dataset_uploads" => 1,
        "fx_daily_rates" => 2,
        "fx_rate_gaps" => 1,
        "fx_rate_uploads" => 1
      )

      expect(Run.exists?(demo_run.id)).to eq(false)
      expect(Run.exists?(non_demo_run.id)).to eq(true)
      expect(DemoDatasetUpload.count).to eq(0)

      expect(FxRateGap.count).to eq(1)
      expect(FxDailyRate.count).to eq(1)
      expect(FxRateUpload.count).to eq(1)

      state = DemoSandboxState.current
      expect(state.last_reset_at).to be_present
      expect(state.last_reset_status).to eq("success")
      expect(state.last_reset_duration_ms).to be >= 0
      expect(state.last_reset_result["runs"]).to eq(1)

      expect(File.exist?(demo_fx_upload_file.path)).to eq(false)
    ensure
      demo_fx_upload_file&.close!
    end

    it "is idempotent when no demo data exists" do
      described_class.new.call(trigger: "spec")
      result = described_class.new.call(trigger: "spec")

      expect(result).to include(
        "runs" => 0,
        "demo_dataset_uploads" => 0,
        "fx_daily_rates" => 0,
        "fx_rate_gaps" => 0,
        "fx_rate_uploads" => 0
      )
      expect(DemoSandboxState.current.last_reset_status).to eq("success")
    end
  end
end
