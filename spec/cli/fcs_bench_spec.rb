# frozen_string_literal: true

require "open3"
require "tmpdir"
require "rbconfig"
require "json"

RSpec.describe "bin/fcs bench" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:ruby) { RbConfig.ruby }
  let(:fixture) { File.join(root, "lib/fcs/fixtures/benchmark_fixture.json") }

  def output_tmpdir
    base = File.join(root, "output")
    FileUtils.mkdir_p(base)
    Dir.mktmpdir(nil, base)
  end

  it "defaults output-dir to output/fcs/benchmarks when omitted" do
    output_tmpdir do |tmp|
      output_dir = File.join(tmp, "output", "fcs", "benchmarks")
      stdout, stderr, status = Open3.capture3(
        ruby,
        File.join(root, "bin/fcs"),
        "bench",
        "--fixture", fixture,
        "--runs", "1",
        chdir: tmp
      )

      if status.success?
        expect(stderr).to eq("")
        expect(stdout).to include("Bench:")
      else
        payload = JSON.parse(stderr)
        expect(payload["code"]).to eq(FCS::Errors::ERR_VALIDATION)
        expect(stdout).to eq("")
      end
      report_files = Dir.glob(File.join(output_dir, "benchmark_report_*.json"))
      expect(report_files).not_to be_empty
    end
  end

  it "honors explicit output-dir overrides" do
    output_tmpdir do |tmp|
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

      if status.success?
        expect(stderr).to eq("")
        expect(stdout).to include("Bench:")
      else
        payload = JSON.parse(stderr)
        expect(payload["code"]).to eq(FCS::Errors::ERR_VALIDATION)
        expect(stdout).to eq("")
      end
      report_files = Dir.glob(File.join(output_dir, "benchmark_report_*.json"))
      expect(report_files).not_to be_empty
    end
  end
end
