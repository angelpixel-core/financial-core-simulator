# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'rbconfig'
require 'json'
require 'fileutils'

RSpec.describe 'bin/fcs run' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:ruby) { RbConfig.ruby }
  let(:fixture) { File.join(root, 'lib/fcs/fixtures/demo_input.json') }

  it 'is silent by default' do
    Dir.mktmpdir do |tmp|
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stdout).to eq('')
      expect(stderr).to eq('')
    end
  end

  it 'defaults output-dir to output/fcs when omitted' do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, 'output', 'fcs')
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to eq('')
      expect(File.exist?(File.join(output_dir, 'result.json'))).to be(true)
    end
  end

  it 'honors explicit output-dir overrides' do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, 'output', 'custom')
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', 'output/custom',
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to eq('')
      expect(File.exist?(File.join(output_dir, 'result.json'))).to be(true)
    end
  end

  it 'warns when output-dir resolves to repo root' do
    Dir.mktmpdir do |tmp|
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', '.',
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      payload = JSON.parse(stderr)
      expect(payload).to include(
        'code' => 'WARN_UNSAFE_OUTPUT_DIR',
        'what_happened' => 'Output directory resolves to an unsafe path'
      )
      expect(payload.fetch('details')).to include('unsafe_reason' => 'repo_root')
    end
  end

  it 'warns when output-dir resolves outside output/' do
    Dir.mktmpdir do |tmp|
      artifacts_dir = File.expand_path('../artifacts', tmp)
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', '../artifacts',
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      payload = JSON.parse(stderr)
      expect(payload).to include(
        'code' => 'WARN_UNSAFE_OUTPUT_DIR',
        'what_happened' => 'Output directory resolves to an unsafe path'
      )
      expect(payload.fetch('details')).to include('unsafe_reason' => 'outside_output')
    ensure
      FileUtils.rm_rf(artifacts_dir)
    end
  end

  it 'does not warn when output-dir is under output/' do
    Dir.mktmpdir do |tmp|
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', 'output/fcs/custom',
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to eq('')
    end
  end

  it 'prints details when --verbose is set' do
    Dir.mktmpdir do |tmp|
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', File.join(tmp, 'out'),
        '--verbose',
        chdir: root
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to include('[INFO] fcs.run.start')
      expect(stderr).to include('[INFO] fcs.run.done')
      expect(stdout).to include('=== fcs_summary ===')
      expect(stdout).to include('status: success')
      expect(stdout).to include('artifacts:')
      expect(stdout).to include('OK: wrote')
    end
  end

  it 'prints identical CLI summary across repeated verbose runs' do
    Dir.mktmpdir do |tmp|
      out_dir = File.join(tmp, 'out')

      stdout1, _stderr1, status1 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', out_dir,
        '--verbose',
        chdir: root
      )

      stdout2, _stderr2, status2 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', out_dir,
        '--verbose',
        chdir: root
      )

      expect(status1.success?).to be(true)
      expect(status2.success?).to be(true)
      expect(stdout1).to include('=== fcs_summary ===')
      expect(stdout1).to eq(stdout2)
    end
  end

  it 'fails deterministically when --input is missing' do
    stdout, stderr, status = Open3.capture3(
      ruby,
      File.join(root, 'bin/fcs'),
      'run',
      chdir: root
    )

    expect(status.success?).to be(false)
    expect(status.exitstatus).to eq(2)
    expect(stdout).to eq('')

    payload = JSON.parse(stderr)
    expect(payload).to include(
      'code' => FCS::Errors::ERR_VALIDATION,
      'what_happened' => '--input is required'
    )
    expect(payload).to have_key('impact')
    expect(payload).to have_key('next_action')
    expect(payload.fetch('details')).to have_key('usage')
  end

  it 'emits diagnostic payload for invalid input json' do
    Dir.mktmpdir do |tmp|
      bad_input = File.join(tmp, 'bad.json')
      File.write(bad_input, '{ invalid-json')

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', bad_input,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include(
        'code' => FCS::Errors::ERR_INVALID_INPUT,
        'what_happened' => 'Invalid JSON'
      )
      expect(payload).to have_key('impact')
      expect(payload).to have_key('next_action')
      expect(payload.fetch('details')).to include(
        'errorClass' => 'JSON::ParserError',
        'errorCode' => 'INVALID_JSON_SYNTAX'
      )
    end
  end

  it 'prints failure summary in verbose mode when run fails' do
    Dir.mktmpdir do |tmp|
      bad_input = File.join(tmp, 'bad.json')
      File.write(bad_input, '{ invalid-json')

      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', bad_input,
        '--output-dir', File.join(tmp, 'out'),
        '--verbose',
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(stdout).to include('=== fcs_summary ===')
      expect(stdout).to include('status: failure')
      expect(stdout).to include('artifacts:')

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_INVALID_INPUT)
    end
  end

  it 'emits deterministic diagnostic payload for invalid flags' do
    _stdout, stderr, status = Open3.capture3(
      ruby,
      File.join(root, 'bin/fcs'),
      'run',
      '--unknown-flag',
      chdir: root
    )

    expect(status.success?).to be(false)
    expect(status.exitstatus).to eq(2)

    payload = JSON.parse(stderr)
    expect(payload).to include('code' => FCS::Errors::ERR_VALIDATION)
    expect(payload.fetch('what_happened')).to eq('Invalid CLI option')
    expect(payload).to have_key('impact')
    expect(payload).to have_key('next_action')
    expect(payload.fetch('details')).to include('errorClass' => 'OptionParser::InvalidOption')
  end

  it 'classifies missing input file as invalid user input' do
    missing = File.join(root, 'tmp', 'does-not-exist.json')

    _stdout, stderr, status = Open3.capture3(
      ruby,
      File.join(root, 'bin/fcs'),
      'run',
      '--input', missing,
      '--output-dir', File.join(root, 'tmp', 'out-missing'),
      chdir: root
    )

    expect(status.success?).to be(false)
    expect(status.exitstatus).to eq(2)

    payload = JSON.parse(stderr)
    expect(payload).to include(
      'code' => FCS::Errors::ERR_INVALID_INPUT,
      'what_happened' => 'Input file not found'
    )
    expect(payload.fetch('details')).to include('path' => missing)
  end

  it 'produces identical artifacts across repeated runs with same input' do
    Dir.mktmpdir do |tmp|
      out1 = File.join(tmp, 'run1')
      out2 = File.join(tmp, 'run2')

      _stdout1, _stderr1, status1 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', out1,
        chdir: root
      )

      _stdout2, _stderr2, status2 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', out2,
        chdir: root
      )

      expect(status1.success?).to be(true)
      expect(status2.success?).to be(true)

      %w[result.json positions.csv pnl.csv].each do |name|
        expect(File.read(File.join(out1, name))).to eq(File.read(File.join(out2, name)))
      end
    end
  end

  it 'keeps the same inputHash for semantically equivalent but reordered input' do
    Dir.mktmpdir do |tmp|
      input_a = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-2' }, { 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'BTC-USD' }, { 'marketId' => 'ETH-USD' }],
        'trades' => [
          {
            'tradeId' => 't-2',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 2,
            'seq' => 2,
            'side' => 'SELL',
            'quantityBase' => '1',
            'priceQuotePerBase' => '120'
          },
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          }
        ],
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
        'markets' => [{ 'marketId' => 'ETH-USD' }, { 'marketId' => 'BTC-USD' }],
        'priceSnapshot' => {
          'fx' => { 'quoteUsd' => '1' },
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [
            { 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' },
            { 'marketId' => 'BTC-USD', 'priceQuotePerBase' => '50000' }
          ]
        },
        'schemaVersion' => '1.0',
        'trades' => [
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          },
          {
            'tradeId' => 't-2',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 2,
            'seq' => 2,
            'side' => 'SELL',
            'quantityBase' => '1',
            'priceQuotePerBase' => '120'
          }
        ],
        'accounts' => [{ 'accountId' => 'acc-1' }, { 'accountId' => 'acc-2' }]
      }

      path_a = File.join(tmp, 'input_a.json')
      path_b = File.join(tmp, 'input_b.json')
      File.write(path_a, JSON.pretty_generate(input_a))
      File.write(path_b, JSON.pretty_generate(input_b))

      out_a = File.join(tmp, 'out-a')
      out_b = File.join(tmp, 'out-b')

      _stdout_a, _stderr_a, status_a = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', path_a,
        '--output-dir', out_a,
        chdir: root
      )

      _stdout_b, _stderr_b, status_b = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', path_b,
        '--output-dir', out_b,
        chdir: root
      )

      expect(status_a.success?).to be(true)
      expect(status_b.success?).to be(true)

      payload_a = JSON.parse(File.read(File.join(out_a, 'result.json')))
      payload_b = JSON.parse(File.read(File.join(out_b, 'result.json')))
      expect(payload_a.fetch('inputHash')).to eq(payload_b.fetch('inputHash'))
    end
  end

  it 'changes inputHash when fee CLI override changes effective execution config' do
    Dir.mktmpdir do |tmp|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100',
            'fee' => { 'amountQuote' => '1' }
          }
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'fee-input.json')
      File.write(input_path, JSON.pretty_generate(input))

      out_fee_on = File.join(tmp, 'out-fee-on')
      out_fee_off = File.join(tmp, 'out-fee-off')

      _stdout_on, _stderr_on, status_on = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', out_fee_on,
        chdir: root
      )

      _stdout_off, _stderr_off, status_off = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', out_fee_off,
        '--no-fee',
        chdir: root
      )

      expect(status_on.success?).to be(true)
      expect(status_off.success?).to be(true)

      payload_on = JSON.parse(File.read(File.join(out_fee_on, 'result.json')))
      payload_off = JSON.parse(File.read(File.join(out_fee_off, 'result.json')))

      expect(payload_on.fetch('inputHash')).not_to eq(payload_off.fetch('inputHash'))
      expect(payload_on.fetch('global').fetch('feesQuote')).not_to eq(payload_off.fetch('global').fetch('feesQuote'))
    end
  end

  it 'allows invalid fee payload when --no-fee disables fee validation path' do
    Dir.mktmpdir do |tmp|
      input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => true },
        'trades' => [
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100',
            'fee' => { 'amountQuote' => 'invalid-fee' }
          }
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'invalid-fee.json')
      File.write(input_path, JSON.pretty_generate(input))

      _stdout_fail, stderr_fail, status_fail = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out-fee-on'),
        chdir: root
      )

      expect(status_fail.success?).to be(false)
      expect(JSON.parse(stderr_fail)).to include('code' => FCS::Errors::ERR_VALIDATION)

      _stdout_ok, _stderr_ok, status_ok = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out-fee-off'),
        '--no-fee',
        chdir: root
      )

      expect(status_ok.success?).to be(true)
    end
  end

  it 'emits stable error envelope for invalid schema and broken references' do
    Dir.mktmpdir do |tmp|
      bad_schema = {
        'schemaVersion' => '9.9',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2500' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      broken_refs = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'BTC-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          }
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '2500' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      schema_path = File.join(tmp, 'bad_schema.json')
      refs_path = File.join(tmp, 'broken_refs.json')
      File.write(schema_path, JSON.pretty_generate(bad_schema))
      File.write(refs_path, JSON.pretty_generate(broken_refs))

      [
        [schema_path, FCS::Errors::ERR_UNSUPPORTED_SCHEMA],
        [refs_path, FCS::Errors::ERR_UNKNOWN_REFERENCE]
      ].each do |input_path, expected_code|
        _stdout, stderr, status = Open3.capture3(
          ruby,
          File.join(root, 'bin/fcs'),
          'run',
          '--input', input_path,
          '--output-dir', File.join(tmp, "out-#{expected_code}"),
          chdir: root
        )

        expect(status.success?).to be(false)
        expect(status.exitstatus).to eq(2)

        payload = JSON.parse(stderr)
        expect(payload).to include('what_happened', 'impact', 'next_action', 'details')
        expect(payload.fetch('error')).to include('code' => expected_code)
        expect(payload.fetch('error')).to have_key('message')
      end
    end
  end

  it 'emits stable error envelope for long-only sell overflow' do
    Dir.mktmpdir do |tmp|
      oversell_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'feeModel' => { 'enabled' => false },
        'trades' => [
          {
            'tradeId' => 'b1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '1',
            'priceQuotePerBase' => '100'
          },
          {
            'tradeId' => 's1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 2,
            'seq' => 2,
            'side' => 'SELL',
            'quantityBase' => '2',
            'priceQuotePerBase' => '100'
          }
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'oversell.json')
      File.write(input_path, JSON.pretty_generate(oversell_input))

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_POSITION_NEGATIVE)
      expect(payload.fetch('what_happened')).to include('position negative')
      expect(payload.fetch('impact')).to include('canonical artifacts')
      expect(payload.fetch('next_action')).to include('re-run')
      expect(payload.fetch('details')).to include(
        'accountId' => 'acc-1',
        'marketId' => 'ETH-USD',
        'qty' => '1.0',
        'sellQty' => '2.0'
      )
    end
  end

  it 'emits deterministic ERR_MISSING_SNAPSHOT when fx quoteUsd is missing' do
    Dir.mktmpdir do |tmp|
      missing_fx_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => {}
        }
      }

      input_path = File.join(tmp, 'missing-fx.json')
      File.write(input_path, JSON.pretty_generate(missing_fx_input))

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_MISSING_SNAPSHOT)
      expect(payload.fetch('details')).to include('missingField' => 'priceSnapshot.fx.quoteUsd')
      expect(payload).to include('what_happened', 'impact', 'next_action')
    end
  end

  it 'emits deterministic ERR_MISSING_SNAPSHOT when valuationTimestamp is missing' do
    Dir.mktmpdir do |tmp|
      missing_ts_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'missing-ts.json')
      File.write(input_path, JSON.pretty_generate(missing_ts_input))

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_MISSING_SNAPSHOT)
      expect(payload.fetch('details')).to include('missingField' => 'priceSnapshot.valuationTimestamp')
    end
  end

  it 'emits deterministic ERR_MISSING_SNAPSHOT when fx payload is malformed' do
    Dir.mktmpdir do |tmp|
      malformed_fx_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => 'invalid-fx'
        }
      }

      input_path = File.join(tmp, 'malformed-fx.json')
      File.write(input_path, JSON.pretty_generate(malformed_fx_input))

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_MISSING_SNAPSHOT)
      expect(payload.fetch('details')).to include('missingField' => 'priceSnapshot.fx.quoteUsd')
      expect(payload).to include('what_happened', 'impact', 'next_action')
    end
  end

  it 'enforces strict positivity while preserving reproducible hash for minimal positive values' do
    Dir.mktmpdir do |tmp|
      invalid_zero_equivalent = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [
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
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      valid_min_positive = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [
          {
            'tradeId' => 't-1',
            'accountId' => 'acc-1',
            'marketId' => 'ETH-USD',
            'timestamp' => 1,
            'seq' => 1,
            'side' => 'BUY',
            'quantityBase' => '0.000000000000000001',
            'priceQuotePerBase' => '100'
          }
        ],
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      invalid_path = File.join(tmp, 'invalid_zero_equivalent.json')
      valid_path = File.join(tmp, 'valid_min_positive.json')
      File.write(invalid_path, JSON.pretty_generate(invalid_zero_equivalent))
      File.write(valid_path, JSON.pretty_generate(valid_min_positive))

      _invalid_stdout, invalid_stderr, invalid_status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', invalid_path,
        '--output-dir', File.join(tmp, 'out-invalid'),
        chdir: root
      )

      expect(invalid_status.success?).to be(false)
      expect(invalid_status.exitstatus).to eq(2)
      invalid_payload = JSON.parse(invalid_stderr)
      expect(invalid_payload).to include('code' => FCS::Errors::ERR_VALIDATION)

      _valid_stdout1, _valid_stderr1, valid_status1 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', valid_path,
        '--output-dir', File.join(tmp, 'out-valid-1'),
        chdir: root
      )

      _valid_stdout2, _valid_stderr2, valid_status2 = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', valid_path,
        '--output-dir', File.join(tmp, 'out-valid-2'),
        chdir: root
      )

      expect(valid_status1.success?).to be(true)
      expect(valid_status2.success?).to be(true)

      payload1 = JSON.parse(File.read(File.join(tmp, 'out-valid-1', 'result.json')))
      payload2 = JSON.parse(File.read(File.join(tmp, 'out-valid-2', 'result.json')))
      expect(payload1.fetch('inputHash')).to eq(payload2.fetch('inputHash'))
    end
  end

  it 'fails deterministically when timeline payload is provided but timeline mode is disabled' do
    previous = ENV.fetch('FCS_TIMELINE_ENABLED', nil)
    ENV['FCS_TIMELINE_ENABLED'] = '0'

    Dir.mktmpdir do |tmp|
      timeline_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
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
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '100' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'timeline.json')
      File.write(input_path, JSON.pretty_generate(timeline_input))

      _stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(false)
      expect(status.exitstatus).to eq(2)

      payload = JSON.parse(stderr)
      expect(payload).to include('code' => FCS::Errors::ERR_VALIDATION)
      expect(payload.fetch('what_happened')).to include('timeline input requires FCS_TIMELINE_ENABLED=1')
    end
  ensure
    ENV['FCS_TIMELINE_ENABLED'] = previous
  end

  it 'applies timeline trades by timelineSeq order in end-to-end CLI flow' do
    previous = ENV.fetch('FCS_TIMELINE_ENABLED', nil)
    ENV['FCS_TIMELINE_ENABLED'] = '1'

    Dir.mktmpdir do |tmp|
      timeline_input = {
        'schemaVersion' => '1.0',
        'accounts' => [{ 'accountId' => 'acc-1' }],
        'markets' => [{ 'marketId' => 'ETH-USD' }],
        'trades' => [],
        'timeline' => {
          'events' => [
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 1,
              'timestamp' => '2026-03-03T12:00:02Z',
              'source' => 'sim.core',
              'externalId' => 'tr-buy',
              'trade' => {
                'tradeId' => 't-buy',
                'accountId' => 'acc-1',
                'marketId' => 'ETH-USD',
                'timestamp' => 2,
                'seq' => 1,
                'side' => 'BUY',
                'quantityBase' => '1',
                'priceQuotePerBase' => '100'
              }
            },
            {
              'eventType' => 'TRADE_APPLIED',
              'timelineSeq' => 2,
              'timestamp' => '2026-03-03T12:00:01Z',
              'source' => 'sim.core',
              'externalId' => 'tr-sell',
              'trade' => {
                'tradeId' => 't-sell',
                'accountId' => 'acc-1',
                'marketId' => 'ETH-USD',
                'timestamp' => 1,
                'seq' => 2,
                'side' => 'SELL',
                'quantityBase' => '1',
                'priceQuotePerBase' => '110'
              }
            }
          ]
        },
        'priceSnapshot' => {
          'valuationTimestamp' => '2026-02-25T03:00:00Z',
          'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '110' }],
          'fx' => { 'quoteUsd' => '1' }
        }
      }

      input_path = File.join(tmp, 'timeline-order.json')
      output_dir = File.join(tmp, 'out')
      File.write(input_path, JSON.pretty_generate(timeline_input))

      _stdout, _stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', input_path,
        '--output-dir', output_dir,
        chdir: root
      )

      expect(status.success?).to be(true)
      payload = JSON.parse(File.read(File.join(output_dir, 'result.json')))
      market = payload.fetch('accounts').first.fetch('markets').first
      expect(market.fetch('quantity')).to eq('0.0')
    end
  ensure
    ENV['FCS_TIMELINE_ENABLED'] = previous
  end
end
