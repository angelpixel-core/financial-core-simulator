# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Ingestion::Validator do
  subject(:validator) { described_class.new }

  def base_input
    {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'trades' => [],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-02-25T03:00:00Z',
        'prices' => [
          { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2500' }
        ],
        'fx' => { 'quoteUsd' => '1' }
      }
    }
  end

  it 'falla si falta priceSnapshot' do
    input = base_input
    input.delete('priceSnapshot')

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        # tu validator actual usa ERR_VALIDATION para missing required field
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'priceSnapshot')
      }
  end

  it 'falla con ERR_MISSING_SNAPSHOT si falta valuationTimestamp' do
    input = base_input
    input['priceSnapshot'].delete('valuationTimestamp')

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to include(missingField: 'priceSnapshot.valuationTimestamp')
      }
  end

  it 'falla con ERR_VALIDATION si valuationTimestamp no es ISO-8601 UTC' do
    input = base_input
    input['priceSnapshot']['valuationTimestamp'] = '2026-02-25 03:00:00'

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'priceSnapshot.valuationTimestamp')
      }
  end

  it 'falla si falta precio para un market' do
    input = base_input
    input['markets'] = [{ 'marketId' => 'ETH-USD' }, { 'marketId' => 'BTC-USD' }]
    # Snapshot solo tiene ETH-USD
    input['priceSnapshot']['prices'] = [
      { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2500' }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to have_key(:missingMarkets)
        expect(e.details[:missingMarkets]).to include('BTC-USD')
      }
  end

  it 'falla con ERR_MISSING_SNAPSHOT si fx existe pero falta quoteUsd' do
    input = base_input
    input['priceSnapshot']['fx'] = {}

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to include(missingField: 'priceSnapshot.fx.quoteUsd')
      }
  end

  it 'falla si snapshot prices contiene marketId duplicado' do
    input = base_input
    input['priceSnapshot']['prices'] = [
      { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2500' },
      { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2550' }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'priceSnapshot.prices.marketId', marketId: 'ETH-USD')
      }
  end

  it 'falla con ERR_MISSING_SNAPSHOT si fx no es un objeto' do
    input = base_input
    input['priceSnapshot']['fx'] = 'invalid-fx'

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(e.details).to include(missingField: 'priceSnapshot.fx.quoteUsd')
      }
  end

  it 'falla si trade referencia market inexistente' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'BTC-USD', # inexistente
        'timestamp' => 1,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_UNKNOWN_REFERENCE)
        expect(e.details).to include(marketId: 'BTC-USD')
      }
  end

  it 'falla con ERR_VALIDATION si trades contiene item no objeto' do
    input = base_input
    input['trades'] = ['invalid-trade-item']

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'trades')
      }
  end

  it 'falla con ERR_VALIDATION si priceSnapshot.prices contiene item no objeto' do
    input = base_input
    input['priceSnapshot']['prices'] = ['invalid-price-item']

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'priceSnapshot.prices')
      }
  end

  it 'falla si hay float en quantityBase' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => 1,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => 1.23, # Float => debe fallar
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_INVALID_NUMBER)
        expect(e.message).to match(/Float not allowed/i)
        expect(e.details).to include(field: 'quantityBase')
      }
  end

  it 'falla si trade no incluye timestamp' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timestamp')
      }
  end

  it 'falla si trade no incluye tradeId valido' do
    input = base_input
    input['trades'] = [
      {
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => 1,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'tradeId')
      }
  end

  it 'falla si quantityBase usa cero equivalente decimal' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => 1,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '0.0',
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'quantityBase', value: '0.0')
      }
  end

  it 'falla si fx quoteUsd usa cero equivalente con leading zeros' do
    input = base_input
    input['priceSnapshot']['fx'] = { 'quoteUsd' => '000' }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'priceSnapshot.fx.quoteUsd', value: '000')
      }
  end

  it 'falla si trade incluye timestamp string en batch' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => '2026-03-03T12:00:01Z',
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timestamp')
      }
  end

  it 'falla con codigo determinista si seq se repite por account+market' do
    input = base_input
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => 1,
        'seq' => 7,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      },
      {
        'tradeId' => 't-2',
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'timestamp' => 2,
        'seq' => 7,
        'side' => 'SELL',
        'quantityBase' => '1',
        'priceQuotePerBase' => '120'
      }
    ]

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_DUPLICATE_SEQ)
        expect(e.details).to include(accountId: 'acc-1', marketId: 'ETH-USD', seq: 7)
      }
  end

  it 'no colisiona seq uniqueness cuando ids contienen separadores' do
    input = base_input
    input['accounts'] = [{ 'accountId' => 'a|b' }, { 'accountId' => 'a' }]
    input['markets'] = [{ 'marketId' => 'c' }, { 'marketId' => 'b|c' }]
    input['priceSnapshot']['prices'] = [
      { 'marketId' => 'c', 'priceQuotePerBase' => '100' },
      { 'marketId' => 'b|c', 'priceQuotePerBase' => '200' }
    ]
    input['trades'] = [
      {
        'tradeId' => 't-1',
        'accountId' => 'a|b',
        'marketId' => 'c',
        'timestamp' => 1,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '100'
      },
      {
        'tradeId' => 't-2',
        'accountId' => 'a',
        'marketId' => 'b|c',
        'timestamp' => 2,
        'seq' => 1,
        'side' => 'BUY',
        'quantityBase' => '1',
        'priceQuotePerBase' => '200'
      }
    ]

    expect { validator.validate!(input) }.not_to raise_error
  end

  it 'falla si evento timeline no incluye eventType' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.eventType')
      }
  end

  it 'falla si evento timeline no incluye timelineSeq' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.timelineSeq')
      }
  end

  it 'falla si evento timeline no incluye source' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.source')
      }
  end

  it 'falla si evento timeline no incluye externalId' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.externalId')
      }
  end

  it 'falla si evento timeline no incluye timestamp' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.timestamp')
      }
  end

  it 'falla si evento timeline usa timestamp no ISO-8601 UTC' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03 12:00:01',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.timestamp')
      }
  end

  it 'acepta timelineSeq no monotono cuando cada valor es unico' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0001',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        },
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 100,
          'timestamp' => '2026-03-03T12:00:02Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-0002',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3152.00'
        }
      ]
    }

    expect { validator.validate!(input) }.not_to raise_error
  end

  it 'falla si hay duplicado exacto de clave idempotente en timeline' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-dup-1',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        },
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-dup-1',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.idempotencyKey')
      }
  end

  it 'falla si hay colision parcial de clave idempotente en timeline' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-col-1',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3151.00'
        },
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 102,
          'timestamp' => '2026-03-03T12:00:02Z',
          'source' => 'feed.binance',
          'externalId' => 'px-ethusd-col-1',
          'marketId' => 'ETH-USD',
          'priceQuotePerBase' => '3152.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_VALIDATION)
        expect(e.details).to include(field: 'timeline.events.externalId')
      }
  end

  it 'falla si TRADE_APPLIED referencia account inexistente en timeline' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'TRADE_APPLIED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'sim.core',
          'externalId' => 'tr-1',
          'trade' => {
            'tradeId' => 't-1',
            'accountId' => 'acc-missing',
            'marketId' => 'ETH-USD',
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          }
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_UNKNOWN_REFERENCE)
        expect(e.details).to include(accountId: 'acc-missing')
      }
  end

  it 'falla si PRICE_UPDATED referencia market inexistente en timeline' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'PRICE_UPDATED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'feed.binance',
          'externalId' => 'px-unknown-1',
          'marketId' => 'BTC-USD',
          'priceQuotePerBase' => '3151.00'
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_UNKNOWN_REFERENCE)
        expect(e.details).to include(marketId: 'BTC-USD')
      }
  end

  it 'falla con ERR_DUPLICATE_SEQ si timeline repite seq por account+market' do
    input = base_input
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'TRADE_APPLIED',
          'timelineSeq' => 101,
          'timestamp' => '2026-03-03T12:00:01Z',
          'source' => 'sim.core',
          'externalId' => 'tr-1',
          'trade' => {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'seq' => 7,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          }
        },
        {
          'eventType' => 'TRADE_APPLIED',
          'timelineSeq' => 102,
          'timestamp' => '2026-03-03T12:00:02Z',
          'source' => 'sim.core',
          'externalId' => 'tr-2',
          'trade' => {
            'tradeId' => 't-2',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'seq' => 7,
            'side' => 'SELL',
            'quantityBase' => '1',
            'priceQuotePerBase' => '110'
          }
        }
      ]
    }

    expect { validator.validate!(input) }
      .to raise_error(FCS::Error) { |e|
        expect(e.code).to eq(FCS::Errors::ERR_DUPLICATE_SEQ)
        expect(e.details).to include(accountId: 'acc-1', marketId: 'ETH-USD', seq: 7)
      }
  end

  it 'ignora trades top-level cuando timeline define trades aplicables' do
    input = base_input
    input['trades'] = ['invalid-top-level-trade']
    input['timeline'] = {
      'events' => [
        {
          'eventType' => 'TRADE_APPLIED',
          'timelineSeq' => 101,
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
    }

    expect { validator.validate!(input) }.not_to raise_error
  end
end
