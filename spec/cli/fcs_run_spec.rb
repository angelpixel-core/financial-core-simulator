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
end
