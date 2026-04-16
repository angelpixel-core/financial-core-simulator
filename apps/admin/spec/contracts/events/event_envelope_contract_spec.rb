require "rails_helper"

RSpec.describe "Event envelope compatibility contract" do
  it "keeps stable envelope fields and event types for canonical events" do
    router = Admin::Events::SchemaRouter.new

    FCS::Events::Catalog::REGISTRY.each do |event_name, metadata|
      envelope = router.route(
        event_name: event_name,
        payload: {runId: 101, status: "succeeded"},
        occurred_at: Time.utc(2026, 4, 16, 12, 0, 0),
        correlation_id: "corr-101",
        source: "contract-test"
      )

      expect(envelope).to include(
        schemaVersion: metadata.fetch(:schema_version),
        eventVersion: metadata.fetch(:event_version),
        eventName: event_name,
        eventType: metadata.fetch(:event_type),
        source: "contract-test",
        correlationId: "corr-101",
        occurredAt: "2026-04-16T12:00:00Z"
      )
      expect(envelope[:payload]).to include(runId: 101)
      expect(envelope[:projections]).to be_an(Array)
    end
  end
end
