require_relative '../../lib/fcs'

RSpec.describe 'Short + margin integration' do
  it 'simulates short flow with risk model and collateral' do
    input = {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1', 'collateralQuote' => '100' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'feeModel' => { 'enabled' => false },
      'riskModel' => { 'maxLeverage' => '2' },
      'trades' => [
        {
          'tradeId' => 's1',
          'accountId' => 'acc-1',
          'marketId' => 'ETH-USD',
          'timestamp' => 1,
          'seq' => 1,
          'side' => 'SELL',
          'quantityBase' => '1',
          'priceQuotePerBase' => '100'
        },
        {
          'tradeId' => 'b1',
          'accountId' => 'acc-1',
          'marketId' => 'ETH-USD',
          'timestamp' => 2,
          'seq' => 2,
          'side' => 'BUY',
          'quantityBase' => '1',
          'priceQuotePerBase' => '80'
        }
      ],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-02-25T03:00:00Z',
        'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '80' }]
      }
    }

    result = FCS::Application::Simulate.new.call(input)
    market = result['accounts'][0]['markets'][0]
    expect(market['realizedPnLQuote']).to eq('20.0')
    expect(market['quantity']).to eq('0.0')
  end
end
