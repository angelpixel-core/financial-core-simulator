# frozen_string_literal: true

RSpec.describe FCS::Engine::FXConverter do
  def build_snapshot(quote_usd: nil, include_fx: true, include_quote_key: false)
    fx = if quote_usd.nil?
      include_quote_key ? {"quoteUsd" => nil} : {}
    else
      {"quoteUsd" => quote_usd}
    end

    include_fx ? {"fx" => fx} : {}
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
      expect(quote_usd.class.name).to eq("FCS::Types::Decimal18")
      expect(quote_usd.atoms).to eq(FCS::Types::Decimal18.from_string("1.25").atoms)
    end

    it "uses injected decimal_klass for quote conversion" do
      marker = Object.new
      decimal_klass = Class.new do
        define_singleton_method(:from_string) do |value|
          raise "unexpected value" unless value == "2.75"

          marker
        end
      end

      converter = described_class.new(
        price_snapshot: build_snapshot(quote_usd: "2.75"),
        usd_enabled: true,
        decimal_klass: decimal_klass
      )

      expect(converter.instance_variable_get(:@quote_usd)).to be(marker)
    end

    it "raises when usd_enabled is true and quoteUsd is missing" do
      expect do
        described_class.new(price_snapshot: build_snapshot, usd_enabled: true)
      end.to raise_error(FCS::Error) do |error|
        expect(error.message).to eq("Missing required snapshot FX rate")
        expect(error.code).to eq(FCS::Errors::ERR_MISSING_SNAPSHOT)
        expect(error.details).to eq(
          missingField: "priceSnapshot.fx.quoteUsd",
          what_happened: "USD conversion is enabled but quoteUsd FX rate is missing from snapshot.",
          impact: "Account and global USD totals cannot be calculated deterministically.",
          next_action: "Provide priceSnapshot.fx.quoteUsd as a positive decimal string, or disable usdModel.enabled."
        )
      end
    end

    it "uses injected error_klass and errors module" do
      custom_errors = Module.new
      custom_errors.const_set(:ERR_MISSING_SNAPSHOT, "CUSTOM_ERR")
      custom_error_klass = Class.new(FCS::Error)

      expect do
        described_class.new(
          price_snapshot: build_snapshot,
          usd_enabled: true,
          error_klass: custom_error_klass,
          errors: custom_errors
        )
      end.to raise_error(custom_error_klass) do |error|
        expect(error.code).to eq("CUSTOM_ERR")
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

    it "raises when usd_enabled is true and quoteUsd is explicitly nil" do
      expect do
        described_class.new(price_snapshot: build_snapshot(quote_usd: nil, include_quote_key: true), usd_enabled: true)
      end.to raise_error(FCS::Error)
    end

    it "does not raise when quoteUsd key is present but nil and usd_enabled is false" do
      converter = nil

      expect do
        converter = described_class.new(
          price_snapshot: build_snapshot(quote_usd: nil, include_quote_key: true),
          usd_enabled: false
        )
      end.not_to raise_error

      expect(converter.instance_variable_get(:@quote_usd)).to be_nil
    end

    it "uses FCS defaults even when local constants exist" do
      stub_const("FCS::Engine::FXConverter::Types", Module.new do
        const_set(:Decimal18, Class.new)
      end)
      stub_const("FCS::Engine::FXConverter::Error", Class.new(StandardError))
      stub_const("FCS::Engine::FXConverter::Errors", Module.new do
        const_set(:ERR_MISSING_SNAPSHOT, "ERR_LOCAL")
      end)

      converter = described_class.new(price_snapshot: build_snapshot(quote_usd: "1.25"), usd_enabled: true)

      expect(converter.instance_variable_get(:@decimal_klass)).to eq(FCS::Types::Decimal18)
      expect(converter.instance_variable_get(:@error_klass)).to eq(FCS::Error)
      expect(converter.instance_variable_get(:@errors)).to eq(FCS::Errors)
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
