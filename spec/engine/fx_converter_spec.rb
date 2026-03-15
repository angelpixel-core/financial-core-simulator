# frozen_string_literal: true

RSpec.describe FCS::Engine::FXConverter do
  def build_snapshot(quote_usd: nil, include_fx: true)
    fx = quote_usd.nil? ? {} : { "quoteUsd" => quote_usd }
    include_fx ? { "fx" => fx } : {}
  end

  describe "#enabled?" do
    it "returns true only when usd_enabled is true and quoteUsd is present" do
      converter = described_class.new(price_snapshot: build_snapshot(quote_usd: "1.25"), usd_enabled: true)

      expect(converter.enabled?).to be(true)
    end

    it "returns false when usd_enabled is false even if quoteUsd is present" do
      converter = described_class.new(price_snapshot: build_snapshot(quote_usd: "1.25"), usd_enabled: false)

      expect(converter.enabled?).to be(false)
    end

    it "returns false when usd_enabled is false and quoteUsd is missing" do
      converter = described_class.new(price_snapshot: build_snapshot, usd_enabled: false)

      expect(converter.enabled?).to be(false)
    end

    it "returns false when usd_enabled is true and quoteUsd is missing" do
      converter = described_class.allocate
      converter.instance_variable_set(:@usd_enabled, true)
      converter.instance_variable_set(:@quote_usd, nil)

      expect(converter.enabled?).to be(false)
    end
  end

  describe "#initialize" do
    it "reads fx.quoteUsd and stores it as Decimal18" do
      converter = described_class.new(price_snapshot: build_snapshot(quote_usd: "1.25"), usd_enabled: true)
      quote_usd = converter.instance_variable_get(:@quote_usd)

      expect(quote_usd).to be_a(FCS::Types::Decimal18)
      expect(quote_usd.atoms).to eq(FCS::Types::Decimal18.from_string("1.25").atoms)
    end

    it "raises when usd_enabled is true and quoteUsd is missing" do
      expect do
        described_class.new(price_snapshot: build_snapshot, usd_enabled: true)
      end.to raise_error(FCS::Error) do |error|
        expect(error.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(error.details).to eq(
          missingField: "priceSnapshot.fx.quoteUsd",
          what_happened: "USD conversion is enabled but quoteUsd FX rate is missing from snapshot.",
          impact: "Account and global USD totals cannot be calculated deterministically.",
          next_action: "Provide priceSnapshot.fx.quoteUsd as a positive decimal string, or disable usdModel.enabled."
        )
      end
    end

    it "does not raise when usd_enabled is false and quoteUsd is missing" do
      expect do
        described_class.new(price_snapshot: build_snapshot, usd_enabled: false)
      end.not_to raise_error
    end

    it "does not raise when fx is missing and usd_enabled is false" do
      converter = nil

      expect do
        converter = described_class.new(price_snapshot: build_snapshot(include_fx: false), usd_enabled: false)
      end.not_to raise_error

      expect(converter.instance_variable_get(:@quote_usd)).to be_nil
    end
  end

  describe "#quote_to_usd" do
    it "multiplies amount_quote by quoteUsd" do
      converter = described_class.new(price_snapshot: build_snapshot(quote_usd: "1.25"), usd_enabled: true)
      amount_quote = FCS::Types::Decimal18.from_string("2.0")

      result = converter.quote_to_usd(amount_quote)

      expect(result.atoms).to eq(FCS::Types::Decimal18.from_string("2.5").atoms)
    end

    it "raises when conversion is not enabled" do
      converter = described_class.new(price_snapshot: build_snapshot, usd_enabled: false)

      expect do
        converter.quote_to_usd(FCS::Types::Decimal18.from_string("1.0"))
      end.to raise_error(FCS::Error) do |error|
        expect(error.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
      end
    end
  end
end
