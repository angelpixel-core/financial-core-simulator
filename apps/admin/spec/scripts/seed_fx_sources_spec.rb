require "rails_helper"

RSpec.describe "seed_fx_sources" do
  before do
    require Rails.root.join("script", "seed_admin")
  end

  it "creates sources from config" do
    FxRateSource.delete_all

    expect do
      SeedAdminFlows.seed_fx_sources
    end.to change(FxRateSource, :count).by_at_least(1)

    source = FxRateSource.find_by(code: "BCRA")
    expect(source).to be_present
    expect(source.source_type).to eq("api")
  end
end
