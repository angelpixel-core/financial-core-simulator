require "rails_helper"
require "json"

RSpec.describe Admin::Observability::StructuredLoggerAdapter do
  it "writes structured JSON entries for info and error" do
    logger = instance_double(Logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    adapter = described_class.new(logger: logger)

    info = adapter.info(event: "runs.execution.completed", payload: {runId: 1}, tags: {status: "succeeded"})
    error = adapter.error(event: "runs.execution.failed", payload: {runId: 1}, tags: {status: "failed"})

    expect(info).to include(event: "runs.execution.completed", payload: {runId: 1})
    expect(error).to include(event: "runs.execution.failed", payload: {runId: 1})

    expect(logger).to have_received(:info) do |message|
      parsed = JSON.parse(message)
      expect(parsed["event"]).to eq("runs.execution.completed")
      expect(parsed["tags"]).to include("status" => "succeeded")
    end
    expect(logger).to have_received(:error) do |message|
      parsed = JSON.parse(message)
      expect(parsed["event"]).to eq("runs.execution.failed")
      expect(parsed["tags"]).to include("status" => "failed")
    end
  end
end
