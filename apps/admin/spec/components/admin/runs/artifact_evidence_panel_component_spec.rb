require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::ArtifactEvidencePanelComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renders descriptive artifact entries with provenance metadata" do
    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: "hash-123",
      artifacts: {
        "result_json_path" => "/tmp/result.json",
        "positions_csv_path" => "/tmp/positions.csv"
      },
      created_at: Time.utc(2026, 3, 14, 3, 10, 0)
    )

    render_inline(described_class.new(run: run))

    expect(rendered_content).to include("Evidencia y artifacts")
    expect(rendered_content).to include("Resultado canonico (JSON)")
    expect(rendered_content).to include("Preview de posiciones")
    expect(rendered_content).to include("<dt>run_id:</dt>")
    expect(rendered_content).to include("<dd>#{run.id}</dd>")
    expect(rendered_content).to include("<dt>input_hash:</dt>")
    expect(rendered_content).to include("<dd>hash-123</dd>")
    expect(rendered_content).to include("<dt>timestamp_utc:</dt>")
    expect(rendered_content).to include("<dt>version:</dt>")
    expect(rendered_content).to include("Estado: complete")
  end

  it "renders unavailable state with icon + text (not color-only)" do
    run = Run.create!(status: :succeeded, verification_status: :verified, input_hash: "hash-999")

    render_inline(described_class.new(run: run))

    expect(rendered_content).to include("Estado: unavailable")
    expect(rendered_content).to include("aria-label=\"Estado del artifact unavailable\"")
  end
end
