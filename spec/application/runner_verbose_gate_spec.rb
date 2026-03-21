# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::Runner do
  let(:input) do
    {
      "schemaVersion" => "1.0",
      "trades" => [],
      "priceSnapshot" => {"valuationTimestamp" => "2026-02-25T03:00:00Z"},
      "feeModel" => {"enabled" => false}
    }
  end

  let(:result) do
    {
      "accounts" => [],
      "global" => {
        "realizedPnLQuote" => "0.0",
        "feesQuote" => "0.0",
        "realizedNetPnLQuote" => "0.0",
        "unrealizedPnLQuote" => "0.0",
        "totalPnLQuote" => "0.0",
        "totalPnLUsd" => nil
      }
    }
  end

  let(:parser) { instance_double(FCS::Ingestion::Parser, parse_file: input) }
  let(:validator) { instance_double(FCS::Ingestion::Validator, validate!: true) }
  let(:sorter) { instance_double(FCS::Engine::TradeSorter, sort: []) }
  let(:simulate) { instance_double(FCS::Application::Simulate, call: result) }
  let(:artifacts_writer) do
    instance_double(
      FCS::Application::ReportArtifactsWriter,
      write_all!: {
        json_path: "output/result.json",
        positions_csv_path: "output/positions.csv",
        pnl_csv_path: "output/pnl.csv"
      }
    )
  end
  let(:cli) { instance_double(FCS::Reporting::CliSummary, print: true) }
  let(:logger) { double("logger", info: true) }

  it "prints summary only when verbose is enabled" do
    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: "input.json", output_dir: "output", fee_enabled: false, verbose: false)
    expect(cli).not_to have_received(:print)

    runner.run!(input_path: "input.json", output_dir: "output", fee_enabled: false, verbose: true)
    expect(cli).to have_received(:print).once
  end

  it "reuses the same runId for reporter payload and CLI summary" do
    writer_payload = nil
    cli_payload = nil
    cli_artifacts = nil
    cli_status = nil

    allow(artifacts_writer).to receive(:write_all!) do |args|
      writer_payload = args.fetch(:payload)
      {
        json_path: "output/result.json",
        positions_csv_path: "output/positions.csv",
        pnl_csv_path: "output/pnl.csv"
      }
    end
    allow(cli).to receive(:print) do |payload, artifacts:, status:|
      cli_payload = payload
      cli_artifacts = artifacts
      cli_status = status
    end

    runner = described_class.new(
      parser: parser,
      validator: validator,
      sorter: sorter,
      simulate: simulate,
      artifacts_writer: artifacts_writer,
      cli: cli,
      logger: logger
    )

    runner.run!(input_path: "input.json", output_dir: "output", fee_enabled: false, verbose: true)

    expect(writer_payload.fetch("runId")).to eq(cli_payload.fetch("runId"))
    expect(cli_artifacts.fetch(:json_path)).to eq("output/result.json")
    expect(cli_status).to eq("success")
    expect(logger).to have_received(:info).at_least(:once)
  end
end
