# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::ReportArtifactsWriter do
  let(:reporter) { instance_double(FCS::Reporting::JsonReport, write!: "out/result.json") }
  let(:positions_csv) { instance_double(FCS::Reporting::CsvPositions, write!: "out/positions.csv") }
  let(:pnl_csv) { instance_double(FCS::Reporting::CsvPnL, write!: "out/pnl.csv") }
  let(:csv_reconciler) { instance_double(FCS::Reporting::CsvArtifactReconciler, validate!: true) }
  let(:account_market_contract_validator) { FCS::Reporting::AccountMarketContractValidator.new }
  let(:result_metadata_contract_validator) { FCS::Reporting::ResultMetadataContractValidator.new }
  let(:account_market_spy) { instance_spy(FCS::Reporting::AccountMarketContractValidator) }
  let(:metadata) do
    {
      "engineVersion" => "0.1.0",
      "schemaVersion" => "1.0",
      "inputHash" => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "runId" => "123e4567-e89b-5d3a-a456-426614174000",
      "valuationTimestamp" => "2026-02-25T03:00:00Z"
    }
  end

  it "writes json and csv artifacts through reporting ports" do
    account_market_spy = instance_spy(FCS::Reporting::AccountMarketContractValidator)
    writer = described_class.new(
      reporter: reporter,
      positions_csv: positions_csv,
      pnl_csv: pnl_csv,
      csv_reconciler: csv_reconciler,
      account_market_contract_validator: account_market_spy,
      result_metadata_contract_validator: result_metadata_contract_validator
    )
    payload = metadata.merge(
      "accounts" => [{ "accountId" => "acc-1", "markets" => [] }],
      "global" => {}
    )

    paths = writer.write_all!(output_dir: "out", payload: payload)

    expect(reporter).to have_received(:write!).with(output_dir: "out", payload: payload)
    expect(positions_csv).to have_received(:write!).with(output_dir: "out", accounts: payload.fetch("accounts"))
    expect(pnl_csv).to have_received(:write!).with(output_dir: "out", accounts: payload.fetch("accounts"))
    expect(csv_reconciler).to have_received(:validate!).with(
      json_path: "out/result.json",
      positions_path: "out/positions.csv",
      pnl_path: "out/pnl.csv"
    )
    expect(paths).to eq(
      json_path: "out/result.json",
      positions_csv_path: "out/positions.csv",
      pnl_csv_path: "out/pnl.csv"
    )
  end

  it "fails with deterministic contract diagnostics when an account-market row misses required metrics" do
    writer = described_class.new(
      reporter: reporter,
      positions_csv: positions_csv,
      pnl_csv: pnl_csv,
      csv_reconciler: csv_reconciler,
      account_market_contract_validator: account_market_contract_validator,
      result_metadata_contract_validator: result_metadata_contract_validator
    )
    payload = metadata.merge(
      "accounts" => [
        {
          "accountId" => "acc-1",
          "markets" => [
            {
              "marketId" => "ETH-USD",
              "quantity" => "1.0",
              "avgCost" => "100.0",
              "realizedPnL" => "0.0"
            }
          ]
        }
      ],
      "global" => {}
    )

    expect do
      writer.write_all!(output_dir: "out", payload: payload)
    end.to raise_error(FCS::Error) do |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details).to include(
        "missing_field" => "accounts[0].markets[0].unrealizedPnL",
        "account_id" => "acc-1",
        "market_id" => "ETH-USD",
        "impact" => "Canonical account-market artifacts cannot be trusted for this run.",
        "next_action" => "Ensure quantity, avgCost, realizedPnL, and unrealizedPnL are present " \
                         "and valid decimal strings for every account-market row."
      )
    end

    expect(reporter).not_to have_received(:write!)
    expect(positions_csv).not_to have_received(:write!)
    expect(pnl_csv).not_to have_received(:write!)
    expect(csv_reconciler).not_to have_received(:validate!)
  end

  it "fails when a required account-market metric is empty or malformed" do
    writer = described_class.new(
      reporter: reporter,
      positions_csv: positions_csv,
      pnl_csv: pnl_csv,
      csv_reconciler: csv_reconciler,
      account_market_contract_validator: account_market_contract_validator,
      result_metadata_contract_validator: result_metadata_contract_validator
    )
    payload = metadata.merge(
      "accounts" => [
        {
          "accountId" => "acc-1",
          "markets" => [
            {
              "marketId" => "ETH-USD",
              "quantity" => "1.0",
              "avgCost" => "",
              "realizedPnL" => "0.0",
              "unrealizedPnL" => "abc"
            }
          ]
        }
      ],
      "global" => {}
    )

    expect do
      writer.write_all!(output_dir: "out", payload: payload)
    end.to raise_error(FCS::Error) do |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details).to include(
        "missing_field" => "accounts[0].markets[0].avgCost",
        "invalid_value" => ""
      )
    end
  end

  it "stops early when metadata contract validation fails" do
    allow(account_market_spy).to receive(:validate!)
    writer = described_class.new(
      reporter: reporter,
      positions_csv: positions_csv,
      pnl_csv: pnl_csv,
      csv_reconciler: csv_reconciler,
      account_market_contract_validator: account_market_spy,
      result_metadata_contract_validator: result_metadata_contract_validator
    )

    payload = metadata.merge(
      "inputHash" => "bad",
      "accounts" => [{ "accountId" => "acc-1", "markets" => [] }],
      "global" => {}
    )

    expect { writer.write_all!(output_dir: "out", payload: payload) }.to raise_error(FCS::Error)

    expect(account_market_spy).not_to have_received(:validate!)
    expect(reporter).not_to have_received(:write!)
    expect(positions_csv).not_to have_received(:write!)
    expect(pnl_csv).not_to have_received(:write!)
    expect(csv_reconciler).not_to have_received(:validate!)
  end
end
