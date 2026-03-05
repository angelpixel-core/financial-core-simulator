require_relative '../../lib/fcs'

RSpec.describe FCS::Projector::TopAccountsRiskProjector do
  subject(:projector) { described_class.new }

  def account_totals_event(account_id:, total_pnl_quote:, realized_net_pnl_quote:, unrealized_pnl_quote:,
                           correlation_id:, occurred_at:)
    {
      'eventVersion' => '1.0',
      'source' => 'aggregator.projector',
      'eventType' => 'ACCOUNT_TOTALS_NORMALIZED',
      'correlationId' => correlation_id,
      'occurredAt' => occurred_at,
      'payload' => {
        'accountId' => account_id,
        'totalPnLQuote' => total_pnl_quote,
        'realizedNetPnLQuote' => realized_net_pnl_quote,
        'unrealizedPnLQuote' => unrealized_pnl_quote
      }
    }
  end

  def risk_snapshot_event(account_id:, status:, margin_ratio:, correlation_id:, occurred_at:)
    {
      'eventVersion' => '1.0',
      'source' => 'aggregator.projector',
      'eventType' => 'RISK_SNAPSHOT_NORMALIZED',
      'correlationId' => correlation_id,
      'occurredAt' => occurred_at,
      'payload' => {
        'accountId' => account_id,
        'status' => status,
        'marginRatio' => margin_ratio
      }
    }
  end

  it 'projects deterministic top-accounts ordered by totalPnlQuote' do
    events = [
      account_totals_event(account_id: 'acc-a', total_pnl_quote: '5.0', realized_net_pnl_quote: '3.0',
                           unrealized_pnl_quote: '2.0', correlation_id: 'corr-a', occurred_at: '2026-03-04T09:00:00Z'),
      account_totals_event(account_id: 'acc-b', total_pnl_quote: '15.0', realized_net_pnl_quote: '11.0',
                           unrealized_pnl_quote: '4.0', correlation_id: 'corr-b', occurred_at: '2026-03-04T09:05:00Z'),
      account_totals_event(account_id: 'acc-c', total_pnl_quote: '9.0', realized_net_pnl_quote: '5.0',
                           unrealized_pnl_quote: '4.0', correlation_id: 'corr-c', occurred_at: '2026-03-04T09:10:00Z')
    ]

    events.each { |event| projector.apply!(event) }

    top_accounts = projector.read_model.fetch('topAccounts')
    expect(top_accounts.map { |row| row.fetch('accountId') }).to eq(%w[acc-b acc-c acc-a])
    expect(top_accounts.first).to include(
      'totalPnLQuote' => '15.0',
      'realizedNetPnLQuote' => '11.0',
      'unrealizedPnLQuote' => '4.0'
    )
  end

  it 'projects per-account risk snapshot view deterministically' do
    events = [
      risk_snapshot_event(account_id: 'acc-a', status: 'HEALTHY', margin_ratio: '1.50', correlation_id: 'corr-1',
                          occurred_at: '2026-03-04T10:00:00Z'),
      risk_snapshot_event(account_id: 'acc-b', status: 'MARGIN_CALL', margin_ratio: '0.95', correlation_id: 'corr-2',
                          occurred_at: '2026-03-04T10:05:00Z')
    ]

    events.each { |event| projector.apply!(event) }

    risk_view = projector.read_model.fetch('riskView')
    expect(risk_view.fetch('acc-a')).to include(
      'status' => 'HEALTHY',
      'marginRatio' => '1.50',
      'correlationId' => 'corr-1'
    )
    expect(risk_view.fetch('acc-b')).to include(
      'status' => 'MARGIN_CALL',
      'marginRatio' => '0.95',
      'correlationId' => 'corr-2'
    )
  end
end
