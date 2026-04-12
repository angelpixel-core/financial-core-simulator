require "rails_helper"

RSpec.describe "Fx sources config" do
  it "loads configured sources for the environment" do
    config = Rails.configuration.x.fx_sources || {}
    resolved = config.respond_to?(:with_indifferent_access) ? config.with_indifferent_access : config
    sources = resolved.fetch(:sources, [])

    expect(sources).to be_an(Array)
    expect(sources).not_to be_empty
    expect(sources.first.keys).to include("code", "source_type", "version", "config")
  end
end
