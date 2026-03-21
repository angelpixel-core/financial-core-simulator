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
          "accounts" => [{"accountId" => "acc-1"}],
          "global" => {"totalPnLQuote" => "10.0"}
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
          "accounts" => [{"accountId" => "acc-1"}],
          "global" => {"totalPnLQuote" => "5.0"}
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
            "state" => {"accounts" => []},
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

  it "returns nil when no checkpoints exist" do
    Dir.mktmpdir do |dir|
      store = described_class.new(
        output_dir: dir,
        checkpoint_every: 3,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      expect(store.latest_checkpoint).to be_nil
    end
  end

  it "persists checkpoints with deterministic filename and loads latest" do
    Dir.mktmpdir do |dir|
      store = described_class.new(
        output_dir: dir,
        checkpoint_every: 1,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      store.write_if_due!(
        event_count: 1,
        timeline_seq: 9,
        state: {"accounts" => [], "global" => {"totalPnLQuote" => "1.0"}},
        input_hash: "hash-1"
      )

      store.write_if_due!(
        event_count: 2,
        timeline_seq: 12,
        state: {"accounts" => [], "global" => {"totalPnLQuote" => "2.0"}},
        input_hash: "hash-2"
      )

      expect(File).to exist(File.join(dir, "checkpoint_9.json"))
      expect(File).to exist(File.join(dir, "checkpoint_12.json"))

      latest = store.latest_checkpoint
      expect(latest.fetch("timelineSeq")).to eq(12)
      expect(latest.fetch("metadata")).to include("inputHash" => "hash-2")
    end
  end

  it "skips checkpoints when interval is zero or invalid" do
    Dir.mktmpdir do |dir|
      zero = described_class.new(
        output_dir: dir,
        checkpoint_every: 0,
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      expect(
        zero.write_if_due!(event_count: 1, timeline_seq: 1, state: {}, input_hash: "hash")
      ).to be_nil

      invalid = described_class.new(
        output_dir: dir,
        checkpoint_every: "nope",
        engine_version: FCS::VERSION,
        schema_version: "1.0"
      )

      expect(
        invalid.write_if_due!(event_count: 1, timeline_seq: 1, state: {}, input_hash: "hash")
      ).to be_nil
    end
  end

  it "raises a schema incompatibility error when schema version mismatches" do
    Dir.mktmpdir do |dir|
      File.write(
        File.join(dir, "checkpoint_3.json"),
        JSON.pretty_generate(
          {
            "timelineSeq" => 3,
            "state" => {"accounts" => []},
            "metadata" => {
              "engineVersion" => FCS::VERSION,
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

      expect { store.latest_checkpoint }.to raise_error(FCS::Error) { |error|
        expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      }
    end
  end
end
