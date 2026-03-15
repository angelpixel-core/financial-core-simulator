require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::RunDiagnosticsPanelComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renders reliability and validation diagnostics together" do
    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      run_uuid: "run-diag-1"
    )

    render_inline(described_class.new(run: run))

    expect(rendered_content).to include("run-reliability-banner")
    expect(rendered_content).to include("validation-issues-panel")
    expect(rendered_content).to include("Estado de confiabilidad")
    expect(rendered_content).to include("Diagnostico de validacion")
  end
end
