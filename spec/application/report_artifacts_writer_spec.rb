require_relative '../../lib/fcs'

RSpec.describe FCS::Application::ReportArtifactsWriter do
  let(:reporter) { instance_double(FCS::Reporting::JsonReport, write!: 'out/result.json') }
  let(:positions_csv) { instance_double(FCS::Reporting::CsvPositions, write!: 'out/positions.csv') }
  let(:pnl_csv) { instance_double(FCS::Reporting::CsvPnL, write!: 'out/pnl.csv') }

  it 'writes json and csv artifacts through reporting ports' do
    writer = described_class.new(reporter: reporter, positions_csv: positions_csv, pnl_csv: pnl_csv)
    payload = {
      'accounts' => [{ 'accountId' => 'acc-1', 'markets' => [] }],
      'global' => {}
    }

    paths = writer.write_all!(output_dir: 'out', payload: payload)

    expect(reporter).to have_received(:write!).with(output_dir: 'out', payload: payload)
    expect(positions_csv).to have_received(:write!).with(output_dir: 'out', accounts: payload.fetch('accounts'))
    expect(pnl_csv).to have_received(:write!).with(output_dir: 'out', accounts: payload.fetch('accounts'))
    expect(paths).to eq(
      json_path: 'out/result.json',
      positions_csv_path: 'out/positions.csv',
      pnl_csv_path: 'out/pnl.csv'
    )
  end

  it 'fails with deterministic contract diagnostics when an account-market row misses required metrics' do
    writer = described_class.new(reporter: reporter, positions_csv: positions_csv, pnl_csv: pnl_csv)
    payload = {
      'accounts' => [
        {
          'accountId' => 'acc-1',
          'markets' => [
            {
              'marketId' => 'ETH-USD',
              'quantity' => '1.0',
              'avgCost' => '100.0',
              'realizedPnL' => '0.0'
            }
          ]
        }
      ],
      'global' => {}
    }

    expect do
      writer.write_all!(output_dir: 'out', payload: payload)
    end.to raise_error(FCS::Error) do |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details).to include(
        'missingField' => 'accounts[0].markets[0].unrealizedPnL',
        'impact' => 'Canonical account-market artifacts cannot be trusted for this run.',
        'nextAction' => 'Ensure quantity, avgCost, realizedPnL, and unrealizedPnL are present for every account-market row.'
      )
    end

    expect(reporter).not_to have_received(:write!)
    expect(positions_csv).not_to have_received(:write!)
    expect(pnl_csv).not_to have_received(:write!)
  end
end
