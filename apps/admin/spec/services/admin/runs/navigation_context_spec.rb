require "rails_helper"

RSpec.describe Admin::Runs::NavigationContext do
  describe ".capture" do
    it "extracts only critical filters and selected run" do
      params = {
        selected_run: "run-42",
        run_status: "succeeded",
        validation_status: "verified",
        date_range: "last_24h",
        correlation_id: "corr-1",
        ignored: "x"
      }

      context = described_class.capture(params: params)

      expect(context).to eq(
        "selected_run" => "run-42",
        "run_status" => "succeeded",
        "validation_status" => "verified",
        "date_range" => "last_24h",
        "correlation_id" => "corr-1"
      )
    end

    it "defaults selected_run from run when missing" do
      run = Run.create!(status: :succeeded)

      context = described_class.capture(params: {}, run: run)

      expect(context).to eq("selected_run" => run.id.to_s)
    end
  end

  describe "#resolve" do
    it "persists incoming context and reuses it on subsequent requests" do
      session = {}

      first = described_class.new(
        params: { selected_run: "run-99", validation_status: "verified" },
        session: session
      ).resolve

      second = described_class.new(params: {}, session: session).resolve

      expect(first).to eq("selected_run" => "run-99", "validation_status" => "verified")
      expect(second).to eq("selected_run" => "run-99", "validation_status" => "verified")
    end
  end
end
