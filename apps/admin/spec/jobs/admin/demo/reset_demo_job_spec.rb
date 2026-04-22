require "rails_helper"

RSpec.describe Admin::Demo::ResetDemoJob, type: :job do
  it "delegates to sandbox reset service" do
    reset_service = instance_double(Admin::Demo::Sandbox::Reset)
    allow(Admin::Demo::Sandbox::Reset).to receive(:new).and_return(reset_service)
    allow(reset_service).to receive(:call)

    described_class.perform_now(trigger: "spec")

    expect(reset_service).to have_received(:call).with(trigger: "spec")
  end
end
