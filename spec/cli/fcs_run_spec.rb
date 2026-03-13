require 'open3'
require 'tmpdir'
require 'rbconfig'
require 'json'

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
      expect(stdout).to include('FCS Summary')
      expect(stdout).to include('OK: wrote')
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
    expect(stderr).to include('ERR: --input is required')
    expect(stdout).to include('Usage: fcs run')
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
      expect(payload).to have_key('details')
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
    expect(payload.fetch('what_happened')).to include('invalid option')
    expect(payload).to have_key('impact')
    expect(payload).to have_key('next_action')
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
end
