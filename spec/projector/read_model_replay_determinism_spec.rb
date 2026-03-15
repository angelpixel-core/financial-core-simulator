require_relative "../../lib/fcs"
require "date"

RSpec.describe FCS::Projector::ReadModelReplay do
  subject(:projector_runtime) { described_class.new(today: Date.new(2026, 3, 4)) }

  def lifecycle_event(status, run_id:, correlation_id:, occurred_at:)
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "RUN_LIFECYCLE_NORMALIZED",
      "correlationId" => correlation_id,
      "occurredAt" => occurred_at,
      "payload" => {
        "runId" => run_id,
        "status" => status
      }
    }
  end

  def account_totals_event(account_id:, total_pnl_quote:, realized_net_pnl_quote:, unrealized_pnl_quote:,
                           correlation_id:, occurred_at:)
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "ACCOUNT_TOTALS_NORMALIZED",
      "correlationId" => correlation_id,
      "occurredAt" => occurred_at,
      "payload" => {
        "accountId" => account_id,
        "totalPnLQuote" => total_pnl_quote,
        "realizedNetPnLQuote" => realized_net_pnl_quote,
        "unrealizedPnLQuote" => unrealized_pnl_quote
      }
    }
  end

  def risk_snapshot_event(account_id:, status:, margin_ratio:, correlation_id:, occurred_at:)
    {
      "eventVersion" => "1.0",
      "source" => "aggregator.projector",
      "eventType" => "RISK_SNAPSHOT_NORMALIZED",
      "correlationId" => correlation_id,
      "occurredAt" => occurred_at,
      "payload" => {
        "accountId" => account_id,
        "status" => status,
        "marginRatio" => margin_ratio
      }
    }
  end

  it "rebuilds identical projector state from ordered canonical stream" do
    stream = [
      lifecycle_event("queued", run_id: "run-1", correlation_id: "corr-1", occurred_at: "2026-03-03T10:00:00Z"),
      lifecycle_event("running", run_id: "run-1", correlation_id: "corr-2", occurred_at: "2026-03-03T10:05:00Z"),
      lifecycle_event("succeeded", run_id: "run-1", correlation_id: "corr-3", occurred_at: "2026-03-03T10:10:00Z"),
      lifecycle_event("failed", run_id: "run-2", correlation_id: "corr-4", occurred_at: "2026-03-04T10:00:00Z"),
      account_totals_event(account_id: "acc-a", total_pnl_quote: "5.0", realized_net_pnl_quote: "3.0",
                           unrealized_pnl_quote: "2.0", correlation_id: "corr-a", occurred_at: "2026-03-04T10:00:30Z"),
      account_totals_event(account_id: "acc-b", total_pnl_quote: "15.0", realized_net_pnl_quote: "11.0",
                           unrealized_pnl_quote: "4.0", correlation_id: "corr-b", occurred_at: "2026-03-04T10:01:00Z"),
      risk_snapshot_event(account_id: "acc-a", status: "HEALTHY", margin_ratio: "1.50", correlation_id: "corr-r1",
                          occurred_at: "2026-03-04T10:01:30Z"),
      risk_snapshot_event(account_id: "acc-b", status: "MARGIN_CALL", margin_ratio: "0.95", correlation_id: "corr-r2",
                          occurred_at: "2026-03-04T10:02:00Z")
    ]

    online_state = projector_runtime.apply_stream!(stream)

    replay_state = described_class
                   .new(today: Date.new(2026, 3, 4))
                   .rebuild_from_stream!(stream)

    expect(replay_state).to eq(online_state)
  end
end
