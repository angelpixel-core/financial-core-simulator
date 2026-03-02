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
end
