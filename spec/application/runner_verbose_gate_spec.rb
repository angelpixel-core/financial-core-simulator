require_relative '../../lib/fcs'

RSpec.describe FCS::Application::Runner do
  let(:input) do
    {
      'schemaVersion' => '1.0',
      'trades' => [],
      'priceSnapshot' => { 'valuationTimestamp' => '2026-02-25T03:00:00Z' },
      'feeModel' => { 'enabled' => false }
    }
  end

  let(:result) do
    {
      'accounts' => [],
      'global' => {
        'realizedPnLQuote' => '0.0',
        'feesQuote' => '0.0',
        'realizedNetPnLQuote' => '0.0',
        'unrealizedPnLQuote' => '0.0',
        'totalPnLQuote' => '0.0',
        'totalPnLUsd' => nil
      }
    }
  end

  let(:parser) { instance_double(FCS::Ingestion::Parser, parse_file: input) }
  let(:validator) { instance_double(FCS::Ingestion::Validator, validate!: true) }
  let(:sorter) { instance_double(FCS::Engine::TradeSorter, sort: []) }
  let(:simulate) { instance_double(FCS::Application::Simulate, call: result) }
  let(:artifacts_writer) do
    instance_double(
      FCS::Application::ReportArtifactsWriter,
      write_all!: {
        json_path: 'output/result.json',
        positions_csv_path: 'output/positions.csv',
        pnl_csv_path: 'output/pnl.csv'
      }
    )
  end
  let(:cli) { instance_double(FCS::Reporting::CliSummary, print: true) }
  let(:logger) { double('logger', info: true) }

  it 'prints summary only when verbose is enabled' do
    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false, verbose: false)
    expect(cli).not_to have_received(:print)

    runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false, verbose: true)
    expect(cli).to have_received(:print).once
  end

  it 'reuses the same runId for reporter payload and CLI summary' do
    allow(SecureRandom).to receive(:uuid).and_return('run-123')

    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false, verbose: true)

    expect(artifacts_writer).to have_received(:write_all!).with(hash_including(payload: hash_including('runId' => 'run-123')))
    expect(cli).to have_received(:print).with(hash_including('runId' => 'run-123'))
    expect(logger).to have_received(:info).at_least(:once)
  end
end
