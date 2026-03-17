# frozen_string_literal: true

require_relative "../../lib/fcs"

RSpec.describe FCS::Types::Decimal18 do
  it "builds from rational and string" do
    from_rat = described_class.from_rational(1, 2)
    from_str = described_class.from_string("0.5")

    expect(from_rat.atoms).to eq(from_str.atoms)
  end

  it "supports arithmetic operations" do
    a = described_class.from_string("2.5")
    b = described_class.from_string("1.5")

    expect((a + b).to_s).to eq("4.0")
    expect((a - b).to_s).to eq("1.0")
    expect((a * b).to_s).to eq("3.75")
    expect((a / b).to_s).to eq("1.666666666666666666")
  end

  it "raises on invalid inputs" do
    expect { described_class.new("1") }
      .to raise_error(ArgumentError, "atoms must be Integer")
    expect { described_class.from_rational(1, 0) }
      .to raise_error(ArgumentError, "den must be > 0")
    expect { described_class.from_rational("1", 1) }
      .to raise_error(ArgumentError, "num must be Integer")
  end

  it "returns true only when atoms are zero" do
    expect(described_class.new(0).zero?).to be(true)
    expect(described_class.new(10).zero?).to be(false)
  end

  it "raises on division by zero" do
    numerator = described_class.from_string("1")
    zero = described_class.new(0)

    expect { numerator / zero }.to raise_error(ZeroDivisionError)
  end
end
