# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::Runner do
  def runner_with(sorter:)
    described_class.new(
      parser: instance_double(FCS::Ingestion::Parser),
      validator: instance_double(FCS::Ingestion::Validator),
      sorter: sorter,
      simulate: instance_double(FCS::Application::Simulate),
      artifacts_writer: instance_double(FCS::Application::ReportArtifactsWriter),
      cli: instance_double(FCS::Reporting::CliSummary),
      logger: instance_double(FCS::Logging::SimpleLogger, info: nil)
    )
  end

  it "normalizes accounts, markets, and prices deterministically" do
    runner = runner_with(sorter: instance_double(FCS::Engine::TradeSorter))

    input = {
      "accounts" => [
        { "accountId" => "b" },
        { "accountId" => "a" }
      ],
      "markets" => [
        { "marketId" => "m-2" },
        { "marketId" => "m-1" }
      ],
      "priceSnapshot" => {
        "prices" => [
          { "marketId" => "m-2" },
          { "marketId" => "m-1" }
        ]
      }
    }

    runner.send(:normalize_collections_for_determinism!, input)

    expect(input.fetch("accounts").map { |a| a.fetch("accountId") }).to eq(%w[a b])
    expect(input.fetch("markets").map { |m| m.fetch("marketId") }).to eq(%w[m-1 m-2])
    expect(input.dig("priceSnapshot", "prices").map { |p| p.fetch("marketId") }).to eq(%w[m-1 m-2])
  end

  it "prepares batch input by removing timeline and sorting trades" do
    sorter = instance_double(FCS::Engine::TradeSorter)
    runner = runner_with(sorter: sorter)

    input = {
      "timeline" => { "events" => [] },
      "trades" => [{ "tradeId" => "t-1" }]
    }

    expect(sorter).to receive(:sort).with(input.fetch("trades")).and_return(["sorted"])

    result = runner.send(:prepare_batch_input, input)

    expect(result).not_to have_key("timeline")
    expect(result.fetch("trades")).to eq(["sorted"])
  end

  it "prepares timeline input by sorting events and extracting trades" do
    runner = runner_with(sorter: instance_double(FCS::Engine::TradeSorter))

    input = {
      "timeline" => {
        "events" => [
          { "timelineSeq" => 2, "eventType" => "TRADE_APPLIED", "trade" => { "tradeId" => "t-2" } },
          { "timelineSeq" => 1, "eventType" => "PRICE_UPDATED" },
          { "timelineSeq" => 3, "eventType" => "TRADE_APPLIED", "trade" => { "tradeId" => "t-3" } }
        ]
      }
    }

    result = runner.send(:prepare_timeline_input, input)

    expect(result.dig("timeline", "events").map { |e| e.fetch("timelineSeq") }).to eq([1, 2, 3])
    expect(result.fetch("trades")).to eq([{ "tradeId" => "t-2" }, { "tradeId" => "t-3" }])
  end

  it "builds replay metadata only when timeline events exist" do
    runner = runner_with(sorter: instance_double(FCS::Engine::TradeSorter))

    input = { "timeline" => { "events" => [{}] } }
    metadata = runner.send(:build_replay_metadata, input: input, checkpoint: { "timelineSeq" => 5 })

    expect(metadata).to include("mode" => "timeline", "checkpointTimelineSeq" => 5)

    expect(
      runner.send(:build_replay_metadata, input: { "timeline" => nil }, checkpoint: nil)
    ).to be_nil
  end

  it "builds checkpoint store only when timeline is enabled and interval positive" do
    runner = runner_with(sorter: instance_double(FCS::Engine::TradeSorter))

    begin
      ENV["FCS_TIMELINE_ENABLED"] = "1"
      ENV["FCS_CHECKPOINT_EVERY"] = "0"
      expect(runner.send(:build_checkpoint_store, output_dir: "out", schema_version: "1.0")).to be_nil

      ENV["FCS_CHECKPOINT_EVERY"] = "5"
      store = runner.send(:build_checkpoint_store, output_dir: "out", schema_version: "1.0")
      expect(store).to be_a(FCS::Application::CheckpointStore)
    ensure
      ENV.delete("FCS_TIMELINE_ENABLED")
      ENV.delete("FCS_CHECKPOINT_EVERY")
    end
  end

  it "creates deterministic run ids from input hash" do
    runner = runner_with(sorter: instance_double(FCS::Engine::TradeSorter))

    first = runner.send(:deterministic_run_id, "hash-1")
    second = runner.send(:deterministic_run_id, "hash-1")
    other = runner.send(:deterministic_run_id, "hash-2")

    expect(first).to eq(second)
    expect(first).not_to eq(other)
    expect(first).to match(/\A[0-9a-f-]{36}\z/)
  end
end
