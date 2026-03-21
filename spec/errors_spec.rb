# frozen_string_literal: true

require_relative "../lib/fcs"

RSpec.describe FCS::Error do
  it "stores code and details" do
    error = described_class.new("ERR_TEST", "message", details: {"a" => 1})

    expect(error.code).to eq("ERR_TEST")
    expect(error.details).to eq("a" => 1)
    expect(error.message).to eq("message")
  end

  it "defaults message to code" do
    error = described_class.new("ERR_TEST")
    expect(error.message).to eq("ERR_TEST")
  end
end
