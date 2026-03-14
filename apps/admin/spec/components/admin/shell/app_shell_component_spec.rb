require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Shell::AppShellComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renders sidebar links and topbar actions" do
    sidebar_items = [
      { label: "Overview", path: "/admin/overview", active: true },
      { label: "Runs", path: "/admin/runs" }
    ]
    breadcrumb = [
      { label: "Workspace", path: "/admin/overview" },
      { label: "Overview" }
    ]
    primary_action = { label: "Open Latest Reliable Run", path: "/runs/12" }

    render_inline(described_class.new(
      sidebar_items: sidebar_items,
      breadcrumb: breadcrumb,
      environment: "test",
      primary_action: primary_action
    )) { "Main content" }

    expect(rendered_content).to include("Overview")
    expect(rendered_content).to include("Runs")
    expect(rendered_content).to include("Open Latest Reliable Run")
    expect(rendered_content).to include("Main content")
    expect(rendered_content).to include("aria-label=\"Workspace navigation\"")
    expect(rendered_content).to include("aria-label=\"Workspace topbar\"")
    expect(rendered_content).to include("Saltar al contenido principal")
    expect(rendered_content).to include("href=\"#workspace-main\"")
    expect(rendered_content).to include("aria-current=&quot;page&quot;")
    expect(rendered_content).to include("id=\"workspace-main\"")
    expect(rendered_content).to include("Menu")
    expect(rendered_content).to include("aria-label=\"Workspace navigation mobile\"")
  end
end
