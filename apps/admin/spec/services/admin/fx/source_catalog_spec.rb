require "rails_helper"

RSpec.describe Admin::Fx::SourceCatalog do
  it "syncs configured sources and exposes available markets" do
    FxRateSource.delete_all

    sources = described_class.active_sources

    bcra = sources.find { |source| source.code == "BCRA" }
    expect(bcra).to be_present
    expect(described_class.available_markets_for(bcra)).to eq(["USDARS", "EURARS"])

    binance = sources.find { |source| source.code == "BINANCE_SPOT" }
    expect(binance).to be_present
    expect(described_class.available_markets_for(binance)).to eq(["BTCUSDT", "ETHUSDT"])
  end
end
