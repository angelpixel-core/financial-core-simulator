# frozen_string_literal: true

require_relative "../lib/fcs"

RSpec.describe "FCS smoke" do
  it "has a version" do
    expect(FCS::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "Decimal18 is deterministic" do
    a = FCS::Types::Decimal18.from_string("1.5")
    b = FCS::Types::Decimal18.from_string("2.0")
    expect((a * b).to_s).to eq("3.0")
  end
end
