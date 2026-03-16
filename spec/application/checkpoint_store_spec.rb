# frozen_string_literal: true

require_relative "../../lib/fcs"
require "tmpdir"
require "json"

RSpec.describe FCS::Application::CheckpointStore do
  it "generates a checkpoint when event threshold is reached with integrity metadata" do
    Dir.mktmpdir do |dir|
      store = described_class.new(
        output_dir: dir,
        checkpoint_every: 3,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      checkpoint = store.write_if_due!(
        event_count: 3,
        timeline_seq: 103,
        state: {
          "accounts" => [{ "accountId" => "acc-1" }],
          "global" => { "totalPnLQuote" => "10.0" }
        },
        input_hash: "abc123"
      )

      expect(checkpoint).to include(
        "timelineSeq" => 103,
        "state" => include("global" => include("totalPnLQuote" => "10.0")),
        "metadata" => include(
          "engineVersion" => FCS::VERSION,
          "schemaVersion" => "1.0",
          "inputHash" => "abc123",
          "stateHash" => kind_of(String)
        )
      )
    end
  end

  it "does not generate intermediate checkpoint when threshold is not reached" do
    Dir.mktmpdir do |dir|
      store = described_class.new(
        output_dir: dir,
        checkpoint_every: 3,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      checkpoint = store.write_if_due!(
        event_count: 2,
        timeline_seq: 102,
        state: {
          "accounts" => [{ "accountId" => "acc-1" }],
          "global" => { "totalPnLQuote" => "5.0" }
        },
        input_hash: "abc123"
      )

      expect(checkpoint).to be_nil
      expect(Dir.glob(File.join(dir, "*.json"))).to eq([])
    end
  end

  it "rejects latest checkpoint when metadata is incompatible" do
    Dir.mktmpdir do |dir|
      File.write(
        File.join(dir, "checkpoint_10.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 10,
            "state" => { "accounts" => [] },
            "metadata" => {
              "engineVersion" => "legacy-engine",
              "schemaVersion" => "2.0",
              "inputHash" => "abc123",
              "stateHash" => "state-hash"
            }
          }
        )
      )

      store = described_class.new(
        output_dir: dir,
        checkpoint_every: 3,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      expect { store.latest_checkpoint }.to raise_error(FCS::Error)
    end
  end
end
