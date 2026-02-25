# frozen_string_literal: true

require_relative "../lib/fcs"

RSpec.describe FCS::Hashing do
  it "produces stable sha256 for same semantic hash order" do
    a = { "schemaVersion" => "1.0", "x" => { "b" => 2, "a" => 1 } }
    b = { "x" => { "a" => 1, "b" => 2 }, "schemaVersion" => "1.0" }

    ca = FCS::Hashing::CanonicalJSON.dump(a)
    cb = FCS::Hashing::CanonicalJSON.dump(b)

    expect(ca).to eq(cb)
    expect(FCS::Hashing::SHA256.hex(ca)).to eq(FCS::Hashing::SHA256.hex(cb))
  end
end
