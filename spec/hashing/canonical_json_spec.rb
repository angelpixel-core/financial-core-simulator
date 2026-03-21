# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Hashing::CanonicalJSON do
  it "sorts hash keys deterministically" do
    input = {"b" => 1, "a" => {"d" => 2, "c" => 3}}
    normalized = described_class.normalize(input)

    expect(normalized.keys).to eq(%w[a b])
    expect(normalized.fetch("a").keys).to eq(%w[c d])
  end

  it "dumps canonical json" do
    input = {"b" => 1, "a" => 2}
    expect(described_class.dump(input)).to eq("{\"a\":2,\"b\":1}")
  end
end
