# frozen_string_literal: true

require "open3"
require "tmpdir"
require "rbconfig"
require "json"

RSpec.describe "bin/fcs bench" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ruby) { RbConfig.ruby }
  let(:fixture) { File.join(root, "lib/fcs/fixtures/benchmark_fixture.json") }

  it "defaults output-dir to output/fcs/benchmarks when omitted" do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, "output", "fcs", "benchmarks")
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, "bin/fcs"),
        "bench",
        "--fixture", fixture,
        "--runs", "1",
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to eq("")
      report_files = Dir.glob(File.join(output_dir, "benchmark_report_*.json"))
      expect(report_files).not_to be_empty
      expect(stdout).to include("Bench:")
    end
  end

  it "honors explicit output-dir overrides" do
    Dir.mktmpdir do |tmp|
      output_dir = File.join(tmp, "output", "benchmarks")
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, "bin/fcs"),
        "bench",
        "--fixture", fixture,
        "--runs", "1",
        "--output-dir", "output/benchmarks",
        chdir: tmp
      )

      expect(status.success?).to be(true), "exit=#{status.exitstatus} stdout=#{stdout.inspect} stderr=#{stderr.inspect}"
      expect(stderr).to eq("")
      report_files = Dir.glob(File.join(output_dir, "benchmark_report_*.json"))
      expect(report_files).not_to be_empty
      expect(stdout).to include("Bench:")
    end
  end
end
