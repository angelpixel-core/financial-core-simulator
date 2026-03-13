# frozen_string_literal: true

require_relative '../../lib/fcs'
require 'json'
require 'tmpdir'
require 'csv'

RSpec.describe 'CSV outputs' do
  it 'writes positions.csv and pnl.csv' do
    Dir.mktmpdir do |dir|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [
          {
            'tradeId' => 'b1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '2',
            'priceQuotePerBase' => '100',
            'fee' => { 'amountQuote' => '1' }
          }
        ],
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
      runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true)

      expect(File).to exist(File.join(out_dir, 'positions.csv'))
      expect(File).to exist(File.join(out_dir, 'pnl.csv'))
      expect(File).to exist(File.join(out_dir, 'result.json'))
    end
  end

  it 'keeps CSV contract stable in timeline mode' do
    previous = ENV['FCS_TIMELINE_ENABLED']
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    Dir.mktmpdir do |dir|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-a' }, { 'accountId' => 'acc-b' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }, { 'marketId' => 'BTC-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [],
        'timeline' => {
          'events' => [
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 1,
              'timestamp' => '2026-03-03T12:00:01Z',
              'source' => 'sim.core',
              'externalId' => 'tr-a-eth-buy',
              'trade' => {
                'tradeId' => 't-a-eth-buy',
                'accountId' => 'acc-a',
                'marketId' => 'ETH-USD',
                'timestamp' => 1,
                'seq' => 1,
                'side' => 'BUY',
                'quantityBase' => '2',
                'priceQuotePerBase' => '100',
                'fee' => { 'amountQuote' => '1' }
              }
            },
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 2,
              'timestamp' => '2026-03-03T12:00:02Z',
              'source' => 'sim.core',
              'externalId' => 'tr-b-eth-buy',
              'trade' => {
                'tradeId' => 't-b-eth-buy',
                'accountId' => 'acc-b',
                'marketId' => 'ETH-USD',
                'timestamp' => 2,
                'seq' => 2,
                'side' => 'BUY',
                'quantityBase' => '1',
                'priceQuotePerBase' => '200',
                'fee' => { 'amountQuote' => '2' }
              }
            }
          ]
        },
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [
            { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' },
            { 'marketId' => 'BTC-USD', 'priceQuotePerBase' => '60' }
          ],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(dir, 'input.json')
      File.write(input_path, JSON.pretty_generate(input))

      out_dir = File.join(dir, 'out')
      runner = FCS::Application::Runner.new
      runner.run!(input_path: input_path, output_dir: out_dir, fee_enabled: true)

      positions_rows = CSV.read(File.join(out_dir, 'positions.csv'), headers: true)
      pnl_rows = CSV.read(File.join(out_dir, 'pnl.csv'), headers: true)

      expect(positions_rows.headers).to eq(%w[accountId marketId quantity avgCost])
      expect(pnl_rows.headers).to eq(
        %w[accountId marketId realizedPnLQuote feesQuote realizedNetPnLQuote unrealizedPnLQuote totalPnLQuote]
      )
      expect(positions_rows.size).to eq(4)
      expect(pnl_rows.size).to eq(4)

      positions_by_key = positions_rows.each_with_object({}) do |row, acc|
        acc[[row['accountId'], row['marketId']]] = row.to_h
      end
      pnl_by_key = pnl_rows.each_with_object({}) do |row, acc|
        acc[[row['accountId'], row['marketId']]] = row.to_h
      end

      expect(positions_by_key.fetch(%w[acc-a ETH-USD])).to include(
        'quantity' => '2.0',
        'avgCost' => '100.0'
      )
      expect(positions_by_key.fetch(%w[acc-b ETH-USD])).to include(
        'quantity' => '1.0',
        'avgCost' => '200.0'
      )
      expect(positions_by_key.fetch(%w[acc-a BTC-USD])).to include(
        'quantity' => '0.0',
        'avgCost' => '0.0'
      )
      expect(positions_by_key.fetch(%w[acc-b BTC-USD])).to include(
        'quantity' => '0.0',
        'avgCost' => '0.0'
      )

      expect(pnl_by_key.fetch(%w[acc-a ETH-USD])).to include(
        'feesQuote' => '1.0',
        'unrealizedPnLQuote' => '100.0',
        'totalPnLQuote' => '99.0'
      )
      expect(pnl_by_key.fetch(%w[acc-b ETH-USD])).to include(
        'feesQuote' => '2.0',
        'unrealizedPnLQuote' => '-50.0',
        'totalPnLQuote' => '-52.0'
      )
    end
  ensure
    ENV['FCS_TIMELINE_ENABLED'] = previous
  end

  it 'writes CSV rows in deterministic account and market order' do
    Dir.mktmpdir do |dir|
      accounts = [
        {
          'accountId' => 'acc-b',
          'markets' => [
            {
              'marketId' => 'ETH-USD',
              'quantity' => '1.0',
              'avgCost' => '200.0',
              'realizedPnLQuote' => '0.0',
              'feesQuote' => '2.0',
              'realizedNetPnLQuote' => '-2.0',
              'unrealizedPnLQuote' => '-50.0',
              'totalPnLQuote' => '-52.0'
            },
            {
              'marketId' => 'BTC-USD',
              'quantity' => '0.0',
              'avgCost' => '0.0',
              'realizedPnLQuote' => '0.0',
              'feesQuote' => '0.0',
              'realizedNetPnLQuote' => '0.0',
              'unrealizedPnLQuote' => '0.0',
              'totalPnLQuote' => '0.0'
            }
          ]
        },
        {
          'accountId' => 'acc-a',
          'markets' => [
            {
              'marketId' => 'ETH-USD',
              'quantity' => '2.0',
              'avgCost' => '100.0',
              'realizedPnLQuote' => '0.0',
              'feesQuote' => '1.0',
              'realizedNetPnLQuote' => '-1.0',
              'unrealizedPnLQuote' => '100.0',
              'totalPnLQuote' => '99.0'
            },
            {
              'marketId' => 'BTC-USD',
              'quantity' => '0.0',
              'avgCost' => '0.0',
              'realizedPnLQuote' => '0.0',
              'feesQuote' => '0.0',
              'realizedNetPnLQuote' => '0.0',
              'unrealizedPnLQuote' => '0.0',
              'totalPnLQuote' => '0.0'
            }
          ]
        }
      ]

      positions_path = FCS::Reporting::CsvPositions.new.write!(output_dir: dir, accounts: accounts)
      pnl_path = FCS::Reporting::CsvPnL.new.write!(output_dir: dir, accounts: accounts)

      positions_rows = CSV.read(positions_path, headers: true)
      pnl_rows = CSV.read(pnl_path, headers: true)

      expect(positions_rows.map { |r| [r['accountId'], r['marketId']] }).to eq(
        [%w[acc-a BTC-USD], %w[acc-a ETH-USD], %w[acc-b BTC-USD], %w[acc-b ETH-USD]]
      )
      expect(pnl_rows.map { |r| [r['accountId'], r['marketId']] }).to eq(
        [%w[acc-a BTC-USD], %w[acc-a ETH-USD], %w[acc-b BTC-USD], %w[acc-b ETH-USD]]
      )
    end
  end
end
