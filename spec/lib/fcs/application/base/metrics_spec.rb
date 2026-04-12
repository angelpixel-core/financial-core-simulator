require "spec_helper"
require "fcs/application/base/metrics"

RSpec.describe FCS::Application::Base::NoopMetrics do
  it "accepts increment calls" do
    metrics = described_class.new

    expect { metrics.increment("fcs_fx_ingestion_started_total", tags: {source: "bcra"}) }
      .not_to raise_error
  end

  it "accepts observe calls" do
    metrics = described_class.new

    expect { metrics.observe("fcs_fx_ingestion_duration_ms", 120, tags: {source: "bcra"}) }
      .not_to raise_error
  end
end
