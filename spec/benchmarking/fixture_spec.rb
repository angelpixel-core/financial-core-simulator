# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "json"

RSpec.describe FCS::Benchmarking::Fixture do
  def write_fixture(dir, payload)
    path = File.join(dir, "fixture.json")
    File.write(path, JSON.pretty_generate(payload))
    path
  end

  it "loads a valid fixture and exposes metadata" do
    Dir.mktmpdir do |dir|
      path = write_fixture(
        dir,
        {
          "schemaVersion" => "1.0",
          "fixtureVersion" => "1",
          "trades" => 100_000,
          "accounts" => 5,
          "markets" => 3,
          "valuationTimestamp" => "2026-02-25T03:00:00Z"
        }
      )

      fixture = described_class.load(path: path)

      expect(fixture.schema_version).to eq("1.0")
      expect(fixture.trades).to eq(100_000)
      expect(fixture.accounts).to eq(5)
      expect(fixture.markets).to eq(3)
      expect(fixture.valuation_timestamp).to eq("2026-02-25T03:00:00Z")
      expect(fixture.to_h).to include("schema_version" => "1.0", "trades" => 100_000)
    end
  end

  it "raises when file is missing" do
    expect do
      described_class.load(path: "missing.json")
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
  end

  it "raises when JSON is invalid" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "fixture.json")
      File.write(path, "{not-json")

      expect do
        described_class.load(path: path)
      end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
    end
  end

  it "raises when required fields are missing" do
    Dir.mktmpdir do |dir|
      path = write_fixture(dir, { "schemaVersion" => "1.0" })

      expect do
        described_class.load(path: path)
      end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
    end
  end

  it "validates trade counts, schema version, and valuation timestamp" do
    Dir.mktmpdir do |dir|
      path = write_fixture(
        dir,
        {
          "schemaVersion" => "",
          "fixtureVersion" => "1",
          "trades" => 10,
          "accounts" => 5,
          "markets" => 3,
          "valuationTimestamp" => ""
        }
      )

      expect do
        described_class.load(path: path)
      end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_INVALID_INPUT) }
    end
  end
end
