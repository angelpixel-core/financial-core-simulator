# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Hashing::SHA256 do
  it "returns deterministic hex digest" do
    expect(described_class.hex("hello")).to eq(Digest::SHA256.hexdigest("hello"))
  end
end
