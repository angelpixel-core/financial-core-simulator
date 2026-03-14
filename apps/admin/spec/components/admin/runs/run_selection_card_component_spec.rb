require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::RunSelectionCardComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renders run metadata and CTA" do
    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      duration_ms: 1200,
      created_at: Time.utc(2026, 3, 13, 12, 0, 0)
    )

    render_inline(described_class.new(
      run: run,
      title: "Latest reliable run",
      cta_label: "Open Latest Reliable Run",
      cta_path: "/runs/#{run.id}"
    ))

    expect(rendered_content).to include("Latest reliable run")
    expect(rendered_content).to include("Run ##{run.id}")
    expect(rendered_content).to include("verified")
    expect(rendered_content).to include("Open Latest Reliable Run")
    expect(rendered_content).to include("aria-label=\"Run status: succeeded\"")
  end
end
