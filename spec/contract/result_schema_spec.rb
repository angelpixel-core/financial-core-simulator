# frozen_string_literal: true

require_relative '../../lib/fcs'
require 'json'
require 'tmpdir'

RSpec.describe 'result.json schema contract' do
  def run_with(explain:)
    Dir.mktmpdir do |dir|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(dir, 'input.json')
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, 'out')
      runner = FCS::Application::Runner.new
      json_path = runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true, explain: explain,
                              verbose: false)

      JSON.parse(File.read(json_path))
    end
  end

  it 'matches required shape (explain off)' do
    payload = run_with(explain: false)

    expect(payload.keys).to include('engineVersion', 'schemaVersion', 'inputHash', 'runId', 'valuationTimestamp',
                                    'accounts', 'global')
    expect(payload['schemaVersion']).to eq('1.0')
    expect(payload['accounts']).to be_a(Array)
    expect(payload['global']).to be_a(Hash)

    acc = payload['accounts'][0]
    expect(acc.keys).to include('accountId', 'markets', 'totals', 'riskEvents')
    expect(acc['markets']).to be_a(Array)
    expect(acc['totals']).to be_a(Hash)
    expect(acc['riskEvents']).to be_a(Array)

    m = acc['markets'][0]
    expect(m.keys).to include(
      'marketId', 'quantity', 'avgCost', 'realizedPnLQuote', 'feesQuote',
      'realizedNetPnLQuote', 'unrealizedPnLQuote', 'totalPnLQuote'
    )
    expect(m).not_to have_key('explain')

    gt = payload['global']
    expect(gt.keys).to include('realizedPnLQuote', 'feesQuote', 'realizedNetPnLQuote', 'unrealizedPnLQuote',
                               'totalPnLQuote', 'totalPnLUsd')
    expect(payload).not_to have_key('replay')
  end

  it 'includes explain block when explain is enabled' do
    payload = run_with(explain: true)
    m = payload['accounts'][0]['markets'][0]

    expect(m).to have_key('explain')
    expect(m['explain']).to be_a(Hash)
    expect(m['explain'].keys).to include('snapshotPrice', 'avgCost', 'qty', 'realizedPnLQuote', 'feesQuote',
                                         'unrealizedPnLQuote', 'totalPnLQuote')
  end

  it 'adds replay metadata in timeline mode without breaking required shape' do
    previous = ENV['FCS_TIMELINE_ENABLED']
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    Dir.mktmpdir do |dir|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [],
        'timeline' => {
          'events' => [
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
        },
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(dir, 'input.json')
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, 'out')
      runner = FCS::Application::Runner.new
      json_path = runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true, explain: false,
                              verbose: false)
      payload = JSON.parse(File.read(json_path))

      expect(payload.keys).to include('engineVersion', 'schemaVersion', 'inputHash', 'runId', 'valuationTimestamp',
                                      'accounts', 'global')
      expect(payload).to have_key('replay')
      expect(payload['replay']).to include('mode' => 'timeline')
    end
  ensure
    ENV['FCS_TIMELINE_ENABLED'] = previous
  end

  it 'keeps contract-level inputHash stable for reordered equivalent collections' do
    Dir.mktmpdir do |dir|
      input_a = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-2' }, { 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'BTC-USD' }, { 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [
            { 'marketId' => 'BTC-USD', 'priceQuotePerBase' => '50000' },
            { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' }
          ],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_b = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }, { 'accountId' => 'acc-2' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }, { 'marketId' => 'BTC-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [
            { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' },
            { 'marketId' => 'BTC-USD', 'priceQuotePerBase' => '50000' }
          ],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_a_path = File.join(dir, 'input_a.json')
      input_b_path = File.join(dir, 'input_b.json')
      File.write(input_a_path, JSON.pretty_generate(input_a))
      File.write(input_b_path, JSON.pretty_generate(input_b))

      runner = FCS::Application::Runner.new
      out_a = File.join(dir, 'out_a')
      out_b = File.join(dir, 'out_b')
      json_a = runner.run!(input_path: input_a_path, output_dir: out_a, fee_enabled: true, explain: false,
                           verbose: false)
      json_b = runner.run!(input_path: input_b_path, output_dir: out_b, fee_enabled: true, explain: false,
                           verbose: false)

      payload_a = JSON.parse(File.read(json_a))
      payload_b = JSON.parse(File.read(json_b))

      expect(payload_a.fetch('inputHash')).to eq(payload_b.fetch('inputHash'))
    end
  end
end
