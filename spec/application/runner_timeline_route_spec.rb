require_relative '../../lib/fcs'

RSpec.describe FCS::Application::Runner do
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

  let(:timeline_events) do
    [
      {
        'eventType' => 'TRADE_APPLIED',
        'timelineSeq' => 2,
        'timestamp' => '2026-03-03T12:00:02Z',
        'source' => 'sim.core',
        'externalId' => 'tr-2',
        'trade' => {
          'tradeId' => 't-2',
          'accountId' => 'acc-1',
          'marketId' => 'ETH-USD',
          'timestamp' => 2,
          'seq' => 2,
          'side' => 'SELL',
          'quantityBase' => '1',
          'priceQuotePerBase' => '120'
        }
      },
      {
        'eventType' => 'TRADE_APPLIED',
        'timelineSeq' => 1,
        'timestamp' => '2026-03-03T12:00:01Z',
        'source' => 'sim.core',
        'externalId' => 'tr-1',
        'trade' => {
          'tradeId' => 't-1',
          'accountId' => 'acc-1',
          'marketId' => 'ETH-USD',
          'timestamp' => 1,
          'seq' => 1,
          'side' => 'BUY',
          'quantityBase' => '1',
          'priceQuotePerBase' => '100'
        }
      }
    ]
  end

  let(:base_input) do
    {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'trades' => [],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-03-03T12:00:00Z',
        'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }]
      },
      'timeline' => {
        'events' => timeline_events
      }
    }
  end

  let(:parser) { instance_double(FCS::Ingestion::Parser, parse_file: base_input) }
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
  let(:checkpoint_store) { instance_double(FCS::Application::CheckpointStore, latest_checkpoint: nil) }

  around do |example|
    previous = ENV['FCS_TIMELINE_ENABLED']
    example.run
    ENV['FCS_TIMELINE_ENABLED'] = previous
  end

  it 'uses batch sorter path when timeline feature flag is disabled' do
    ENV['FCS_TIMELINE_ENABLED'] = '0'

    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false)

    expect(sorter).to have_received(:sort).with([])
  end

  it 'routes through timeline events when feature flag is enabled' do
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false)

    expect(sorter).not_to have_received(:sort)
    expect(simulate).to have_received(:call) do |input_arg, **kwargs|
      trade_ids = input_arg.fetch('trades').map { |trade| trade.fetch('tradeId') }
      expect(trade_ids).to eq(%w[t-1 t-2])
      expect(kwargs).to include(checkpoint_store: kind_of(FCS::Application::CheckpointStore))
    end
  end
end
