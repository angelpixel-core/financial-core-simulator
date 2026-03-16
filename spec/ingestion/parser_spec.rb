# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"

RSpec.describe FCS::Ingestion::Parser do
  it "parses JSON input from disk" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "input.json")
      File.write(path, "{\"hello\":\"world\"}")

      payload = described_class.new.parse_file(path)

      expect(payload).to eq("hello" => "world")
    end
  end

  it "raises a validation error when file is missing" do
    expect do
      described_class.new.parse_file("missing.json")
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
  end

  it "raises a validation error when JSON is invalid" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "input.json")
      File.write(path, "{not-json")

      expect do
        described_class.new.parse_file(path)
      end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
    end
  end
end
