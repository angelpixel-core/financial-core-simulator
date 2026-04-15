# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Application::NormalizeFxContext do
  it "builds normalized context payload" do
    result = described_class.new.call(
      reporting_currency: "ARS",
      operator_fee_factor: "1.15",
      rate_data: {rate: "1100.5", rate_source: "manual", rate_missing: false},
      operational_date: Date.new(2026, 3, 30)
    )

    expect(result).to eq(
      "reportingCurrency" => "ARS",
      "operatorFeeFactor" => "1.15",
      "rate" => "1100.5",
      "rateDate" => "2026-03-30",
      "rateSource" => "manual",
      "rateMissing" => false
    )
  end

  it "validates positive fee factor" do
    expect do
      described_class.new.call(
        reporting_currency: "ARS",
        operator_fee_factor: "0",
        rate_data: {rate: nil, rate_source: "missing", rate_missing: true},
        operational_date: Date.new(2026, 3, 30)
      )
    end.to raise_error(ArgumentError, /operator fee factor must be positive/)
  end
end
