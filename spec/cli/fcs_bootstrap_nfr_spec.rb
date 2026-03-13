# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'rbconfig'

RSpec.describe 'Story 1.1 NFR4 bootstrap timing' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:ruby) { RbConfig.ruby }
  let(:fixture) { File.join(root, 'lib/fcs/fixtures/demo_input.json') }

  it 'keeps bootstrap prerequisites plus first successful run under 15 minutes' do
    Dir.mktmpdir do |tmp|
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      _check_out, _check_err, check_status = Open3.capture3('bundle', 'check', chdir: root)

      unless check_status.success?
        _install_out, install_err, install_status = Open3.capture3('bundle', 'install', '--local', chdir: root)
        expect(install_status.success?).to be(true), install_err
      end

      _stdout, _stderr, status = Open3.capture3(
        ruby,
        File.join(root, 'bin/fcs'),
        'run',
        '--input', fixture,
        '--output-dir', File.join(tmp, 'out'),
        chdir: root
      )

      expect(status.success?).to be(true)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

      expect(elapsed).to be <= 900.0
    end
  end
end
