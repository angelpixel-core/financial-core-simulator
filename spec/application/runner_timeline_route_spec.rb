require_relative '../../lib/fcs'
require 'json'
require 'tmpdir'

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

  it 'fails fast when timeline payload is provided but feature flag is disabled' do
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

    expect do
      runner.run!(input_path: 'input.json', output_dir: 'output', fee_enabled: false)
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
    expect(sorter).not_to have_received(:sort)
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

  it 'normalizes timeline events before hashing for deterministic inputHash' do
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    parser_a = instance_double(FCS::Ingestion::Parser, parse_file: base_input)
    parser_b = instance_double(FCS::Ingestion::Parser,
                               parse_file: base_input.merge('timeline' => { 'events' => timeline_events.reverse }))

    input_hashes = []
    simulate_spy = lambda do |_input_arg, **kwargs|
      input_hashes << kwargs.fetch(:input_hash)
      result
    end

    runner_a = described_class.new(
      parser: parser_a,
      validator: validator,
      sorter: sorter,
      simulate: simulate_spy,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner_b = described_class.new(
      parser: parser_b,
      validator: validator,
      sorter: sorter,
      simulate: simulate_spy,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner_a.run!(input_path: 'input_a.json', output_dir: 'output_a', fee_enabled: false)
    runner_b.run!(input_path: 'input_b.json', output_dir: 'output_b', fee_enabled: false)

    expect(input_hashes.size).to eq(2)
    expect(input_hashes.first).to eq(input_hashes.last)
  end

  it 'accepts non-monotonic timeline input and applies trades by timelineSeq in real run' do
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    Dir.mktmpdir do |tmp|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'timeline' => {
          'events' => [
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 2,
              'timestamp' => '2026-03-03T12:00:02Z',
              'source' => 'sim.core',
              'externalId' => 'tr-sell',
              'trade' => {
                'tradeId' => 't-sell',
                'accountId' => 'acc-1',
                'marketId' => 'ETH-USD',
                'timestamp' => 2,
                'seq' => 2,
                'side' => 'SELL',
                'quantityBase' => '1',
                'priceQuotePerBase' => '110'
              }
            },
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 1,
              'timestamp' => '2026-03-03T12:00:01Z',
              'source' => 'sim.core',
              'externalId' => 'tr-buy',
              'trade' => {
                'tradeId' => 't-buy',
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
        },
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-03-03T12:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '110' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'input.json')
      output_dir = File.join(tmp, 'out')
      File.write(input_path, JSON.pretty_generate(input))

      result_path = described_class.new.run!(
        input_path: input_path,
        output_dir: output_dir,
        fee_enabled: false,
        verbose: false
      )

      payload = JSON.parse(File.read(result_path))
      market = payload.fetch('accounts').first.fetch('markets').first
      expect(market.fetch('quantity')).to eq('0.0')
    end
  end
end
