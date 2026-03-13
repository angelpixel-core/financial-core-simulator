require 'open3'
require 'tmpdir'
require 'rbconfig'

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
