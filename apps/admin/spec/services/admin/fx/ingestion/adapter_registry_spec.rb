require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::AdapterRegistry do
  it "builds a BCRA adapter for supported sources" do
    source = FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_url" => "https://api.bcra.gob.ar/estadisticascambiarias/v1.0"}
    )

    adapter = described_class.build(source)

    expect(adapter).to be_a(Admin::Fx::Ingestion::Adapters::BcraAdapter)
  end

  it "returns nil for unknown sources" do
    source = FxRateSource.create!(
      name: "Manual",
      code: "MANUAL",
      source_type: "manual",
      version: "v1",
      config: {"note" => "n/a"}
    )

    expect(described_class.build(source)).to be_nil
  end
end
