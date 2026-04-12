require "spec_helper"
require "fcs/application/base/publisher"
require "fcs/application/base/result"

RSpec.describe FCS::Application::Base::NoopPublisher do
  it "returns a success result without publishing" do
    publisher = described_class.new

    result = publisher.publish(event: {event_type: "fx_rate.ingested"})

    expect(result).to be_success
    expect(result.data).to eq({published: false, event_type: "fx_rate.ingested"})
  end

  it "returns a success result when disabled" do
    publisher = FCS::Application::Base::Publisher.new(enabled: false)

    result = publisher.publish(event: {event_type: "fx_rate.persisted"})

    expect(result).to be_success
    expect(result.data).to eq({published: false, event_type: "fx_rate.persisted"})
  end
end
