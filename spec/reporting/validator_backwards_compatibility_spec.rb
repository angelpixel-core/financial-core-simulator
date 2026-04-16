# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe "Reporting validator backwards compatibility" do
  it "keeps old reporting constants inheriting from relocated contracts" do
    expect(FCS::Reporting::AccountMarketContractValidator < FCS::Contracts::Reporting::AccountMarketContractValidator)
      .to be(true)
    expect(FCS::Reporting::ResultMetadataContractValidator < FCS::Contracts::Reporting::ResultMetadataContractValidator)
      .to be(true)
  end

  it "keeps old result metadata validator behavior intact" do
    validator = FCS::Reporting::ResultMetadataContractValidator.new

    expect do
      validator.validate!(payload: {"schemaVersion" => "1.0"})
    end.to raise_error(FCS::Error) do |error|
      expect(error.code).to eq(FCS::Errors::ERR_VALIDATION)
      expect(error.details).to include("impact", "next_action")
    end
  end
end
