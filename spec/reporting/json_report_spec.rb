# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "json"

RSpec.describe FCS::Reporting::JsonReport do
  it "writes canonical json payload" do
    Dir.mktmpdir do |dir|
      payload = {
        "b" => 1,
        "a" => {"d" => 2, "c" => 3},
        "list" => [{"b" => 1, "a" => 2}]
      }

      path = described_class.new.write!(output_dir: dir, payload: payload)
      written = JSON.parse(File.read(path))

      expect(written.keys).to eq(%w[a b list])
      expect(written.fetch("a").keys).to eq(%w[c d])
    end
  end
end
