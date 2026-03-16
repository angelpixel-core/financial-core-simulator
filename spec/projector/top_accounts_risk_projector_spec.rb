# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Projector::TopAccountsRiskProjector do
  it "updates top accounts only with latest event" do
    projector = described_class.new

    projector.apply!(
      "eventType" => "ACCOUNT_TOTALS_NORMALIZED",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T01:00:00Z",
      "payload" => {
        "accountId" => "acc-1",
        "totalPnLQuote" => "10",
        "realizedNetPnLQuote" => "5",
        "unrealizedPnLQuote" => "5"
      }
    )

    projector.apply!(
      "eventType" => "ACCOUNT_TOTALS_NORMALIZED",
      "correlationId" => "corr-2",
      "occurredAt" => "2026-02-25T00:00:00Z",
      "payload" => {
        "accountId" => "acc-1",
        "totalPnLQuote" => "20",
        "realizedNetPnLQuote" => "10",
        "unrealizedPnLQuote" => "10"
      }
    )

    model = projector.read_model

    expect(model.fetch("topAccounts").first).to include(
      "accountId" => "acc-1",
      "totalPnLQuote" => "10",
      "correlationId" => "corr-1"
    )
  end

  it "updates risk view with latest snapshot" do
    projector = described_class.new

    projector.apply!(
      "eventType" => "RISK_SNAPSHOT_NORMALIZED",
      "correlationId" => "corr-1",
      "occurredAt" => "2026-02-25T01:00:00Z",
      "payload" => {
        "accountId" => "acc-1",
        "status" => "LIQUIDATABLE",
        "marginRatio" => "0.5"
      }
    )

    model = projector.read_model

    expect(model.fetch("riskView").fetch("acc-1")).to include(
      "status" => "LIQUIDATABLE",
      "correlationId" => "corr-1"
    )
  end

  it "rejects invalid occurredAt" do
    projector = described_class.new

    expect do
      projector.apply!(
        "eventType" => "ACCOUNT_TOTALS_NORMALIZED",
        "correlationId" => "corr-1",
        "occurredAt" => "bad",
        "payload" => {
          "accountId" => "acc-1",
          "totalPnLQuote" => "10",
          "realizedNetPnLQuote" => "5",
          "unrealizedPnLQuote" => "5"
        }
      )
    end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: "event.occurredAt") }
  end
end
