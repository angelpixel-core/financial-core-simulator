require_relative '../../lib/fcs'

RSpec.describe FCS::Ingestion::Validator do
  def base_input
    {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'trades' => [],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-02-25T03:00:00Z',
        'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }]
      }
    }
  end

  it 'accepts FIFO accounting model' do
    input = base_input.merge('accountingModel' => { 'method' => 'FIFO' })

    expect { described_class.new.validate!(input) }.not_to raise_error
  end

  it 'rejects unsupported accounting model' do
    input = base_input.merge('accountingModel' => { 'method' => 'LIFO' })

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
    }
  end

  it 'accepts riskModel.maxLeverage and accounts collateralQuote' do
    input = base_input.merge(
      'riskModel' => { 'maxLeverage' => '2' },
      'accounts' => [{ 'accountId' => 'acc-1', 'collateralQuote' => '100' }]
    )

    expect { described_class.new.validate!(input) }.not_to raise_error
  end

  it 'rejects non-positive maxLeverage' do
    input = base_input.merge('riskModel' => { 'maxLeverage' => '0' })

    expect { described_class.new.validate!(input) }.to raise_error(FCS::Error) { |e|
      expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
    }
  end
end
