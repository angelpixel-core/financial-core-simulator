class Admin::DocsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  DOC_SECTIONS = [
    {
      slug: 'system-state',
      title: 'System State',
      description: 'Current system readiness and overall health signals.',
      items: []
    },
    {
      slug: 'simulation-context',
      title: 'Simulation Context',
      description: 'Inputs, assumptions, and deterministic context for runs.',
      items: []
    },
    {
      slug: 'runs',
      title: 'Runs',
      description: 'Execution-level coverage for trades and FX rates.',
      title_key: 'admin.docs.sections.runs.title',
      description_key: 'admin.docs.sections.runs.description',
      items: [],
      children: [
        {
          slug: 'trades',
          title: 'Trades',
          description: 'Trade-level outcomes and input coverage.',
          title_key: 'admin.docs.sections.trades.title',
          description_key: 'admin.docs.sections.trades.description',
          items: []
        },
        {
          slug: 'fx-rates',
          title: 'FX Rates',
          description: 'FX rate inputs, coverage, and overrides.',
          title_key: 'admin.docs.sections.fx_rates.title',
          description_key: 'admin.docs.sections.fx_rates.description',
          items: []
        }
      ]
    },
    {
      slug: 'system-metrics',
      title: 'System Metrics',
      description: 'Operational KPIs and reliability indicators.',
      items: []
    },
    {
      slug: 'activity',
      title: 'Activity',
      description: 'Run activity and status distribution over time.',
      items: [
        'Run trend (14d)',
        'Status mix (30d)'
      ]
    },
    {
      slug: 'financial-results',
      title: 'Financial Results',
      description: 'PnL outcomes and account-level summaries.',
      items: [
        'PnL trend',
        'Latest succeeded run',
        'Global PnL (latest succeeded run)',
        'Top accounts (live)',
        'Run comparison',
        'Input traceability'
      ]
    },
    {
      slug: 'data-quality',
      title: 'Data Quality',
      description: 'Validation errors and ingestion quality signals.',
      items: [
        'Ingestion validation errors'
      ]
    }
  ].freeze

  def index
    @sections = DOC_SECTIONS
  end

  def show
    @section = find_section(DOC_SECTIONS, params[:section])
    return redirect_to admin_docs_path unless @section

    @sections = DOC_SECTIONS
  end

  helper_method :section_title, :section_description

  private

  def find_section(sections, slug)
    sections.each do |section|
      return section if section[:slug] == slug

      child = find_section(section[:children] || [], slug)
      return child if child
    end

    nil
  end

  def section_title(section)
    return section[:title] if section[:title_key].blank?

    t(section[:title_key])
  end

  def section_description(section)
    return section[:description] if section[:description_key].blank?

    t(section[:description_key])
  end

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
