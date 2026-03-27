require "rails_helper"
require "view_component/test_helpers"
require "fileutils"
require "tmpdir"

RSpec.describe Admin::Runs::ArtifactEvidencePanelComponent, type: :component do
  include ViewComponent::TestHelpers

  around do |example|
    I18n.with_locale(:es) { example.run }
  end

  it "renders descriptive artifact entries with provenance metadata" do
    base_dir = Rails.root.join("storage", "runs", "spec_component_artifacts")
    FileUtils.mkdir_p(base_dir)
    result_path = base_dir.join("result.json")
    positions_path = base_dir.join("positions.csv")
    File.write(result_path, "{}")
    File.write(positions_path, "account,qty\nacc-1,10\n")

    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: "hash-123",
      valuation_timestamp: Time.utc(2026, 3, 14, 4, 30, 0),
      artifacts: {
        "result_json_path" => result_path.to_s,
        "positions_csv_path" => positions_path.to_s
      },
      created_at: Time.utc(2026, 3, 14, 3, 10, 0)
    )

    render_inline(described_class.new(run: run))

    expect(rendered_content).to include(I18n.t("admin.runs.artifacts.title"))
    expect(rendered_content).to include(I18n.t("admin.runs.artifacts.entries.result_json.label"))
    expect(rendered_content).to include(I18n.t("admin.runs.artifacts.entries.positions_preview.label"))
    expect(rendered_content).to include("<dt>#{I18n.t("admin.runs.artifacts.provenance.run_id")}:</dt>")
    expect(rendered_content).to include("<dd>#{run.id}</dd>")
    expect(rendered_content).to include("<dt>#{I18n.t("admin.runs.artifacts.provenance.input_hash")}:</dt>")
    expect(rendered_content).to include("<dd>hash-123</dd>")
    expect(rendered_content).to include("<dt>#{I18n.t("admin.runs.artifacts.provenance.timestamp_utc")}:</dt>")
    expect(rendered_content).to include("<dd>2026-03-14T04:30:00Z</dd>")
    expect(rendered_content).to include("<dt>#{I18n.t("admin.runs.artifacts.provenance.version")}:</dt>")
    expect(rendered_content).to include(
      I18n.t("admin.runs.artifacts.status_label", label: I18n.t("admin.runs.artifacts.status.complete"))
    )
    expect(rendered_content).to include('role="status"')
  ensure
    FileUtils.rm_f(result_path) if defined?(result_path)
    FileUtils.rm_f(positions_path) if defined?(positions_path)
  end

  it "renders unavailable state with icon + text (not color-only)" do
    run = Run.create!(status: :succeeded, verification_status: :verified, input_hash: "hash-999")

    render_inline(described_class.new(run: run))

    expect(rendered_content).to include(
      I18n.t("admin.runs.artifacts.status_label", label: I18n.t("admin.runs.artifacts.status.unavailable"))
    )
    expect(rendered_content).to include(
      "aria-label=\"#{I18n.t("admin.runs.artifacts.status_aria", state: "unavailable")}\""
    )
  end

  it "marks artifact as unavailable when path is outside storage root" do
    outside_dir = Dir.mktmpdir
    outside_path = File.join(outside_dir, "result.json")
    File.write(outside_path, "{}")

    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: "hash-777",
      artifacts: {"result_json_path" => outside_path}
    )

    render_inline(described_class.new(run: run))

    unavailable_action = I18n.t(
      "admin.runs.artifacts.unavailable_action",
      label: I18n.t("admin.runs.artifacts.entries.result_json.action")
    )
    expect(rendered_content).to include(unavailable_action)
    expect(rendered_content).to include(
      I18n.t("admin.runs.artifacts.status_label", label: I18n.t("admin.runs.artifacts.status.unavailable"))
    )
  ensure
    FileUtils.remove_entry(outside_dir) if defined?(outside_dir)
  end
end
