class Admin::DocsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  DOC_SECTIONS = [
    {
      slug: "system-state",
      title: "System State",
      description: "Current system readiness and overall health signals.",
      items: []
    },
    {
      slug: "simulation-context",
      title: "Simulation Context",
      description: "Inputs, assumptions, and deterministic context for runs.",
      items: []
    },
    {
      slug: "system-metrics",
      title: "System Metrics",
      description: "Operational KPIs and reliability indicators.",
      items: []
    },
    {
      slug: "activity",
      title: "Activity",
      description: "Run activity and status distribution over time.",
      items: [
        "Run trend (14d)",
        "Status mix (30d)"
      ]
    },
    {
      slug: "financial-results",
      title: "Financial Results",
      description: "PnL outcomes and account-level summaries.",
      items: [
        "PnL trend",
        "Latest succeeded run",
        "Global PnL (latest succeeded run)",
        "Top accounts (live)",
        "Run comparison",
        "Input traceability"
      ]
    },
    {
      slug: "data-quality",
      title: "Data Quality",
      description: "Validation errors and ingestion quality signals.",
      items: [
        "Ingestion validation errors"
      ]
    }
  ].freeze

  def index
    @sections = DOC_SECTIONS
  end

  def show
    @section = DOC_SECTIONS.find { |entry| entry[:slug] == params[:section] }
    return redirect_to admin_docs_path unless @section

    @sections = DOC_SECTIONS
  end

  private

  def load_navigation_context
    @navigation_context = Runs::Api.navigation_context(params: params, session: session)
  end
end
