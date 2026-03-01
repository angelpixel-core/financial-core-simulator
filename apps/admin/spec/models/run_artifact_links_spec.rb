require "rails_helper"

RSpec.describe Run, type: :model do
  describe "artifact links" do
    it "returns unavailable when artifact path is missing" do
      run = described_class.create!(input_json: { "schemaVersion" => "1.0" })

      expect(run.result_json_link).to eq("Unavailable")
    end

    it "returns html links when artifacts are present" do
      run = described_class.create!(
        input_json: { "schemaVersion" => "1.0" },
        artifacts: {
          "result_json_path" => "/tmp/result.json",
          "positions_csv_path" => "/tmp/positions.csv",
          "pnl_csv_path" => "/tmp/pnl.csv"
        }
      )

      expect(run.result_json_link).to include("/runs/#{run.id}/result")
      expect(run.positions_csv_link).to include("/runs/#{run.id}/positions")
      expect(run.pnl_csv_link).to include("/runs/#{run.id}/pnl")
    end
  end
end
