require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::ValidationIssuesPanelComponent, type: :component do
  include ViewComponent::TestHelpers

  around do |example|
    I18n.with_locale(:es) { example.run }
  end

  it "renders success state with empty message" do
    diagnostic = {
      what_happened: "Sin issues",
      impact: "Datos ok",
      next_action: "Continuar"
    }

    render_inline(described_class.new(
      title: "Diagnostico de validacion",
      state: :success,
      diagnostic: diagnostic,
      issues: []
    ))

    expect(rendered_content).to include("validation-issues-panel--success")
    expect(rendered_content).to include(I18n.t("admin.runs.validation_issues.empty"))
    expect(rendered_content).to include(I18n.t("admin.runs.validation_issues.aria",
      state: I18n.t("admin.runs.validation_issues.states.success")))
  end

  it "renders warning state with diagnostic triad" do
    diagnostic = {
      what_happened: "Validacion incompleta",
      impact: "Calidad incierta",
      next_action: "Reintentar"
    }

    render_inline(described_class.new(
      title: "Diagnostico de validacion",
      state: :warning,
      diagnostic: diagnostic,
      issues: []
    ))

    expect(rendered_content).to include("validation-issues-panel--warning")
    expect(rendered_content).to include(I18n.t("admin.common.what_happened"))
    expect(rendered_content).to include(I18n.t("admin.common.impact"))
    expect(rendered_content).to include(I18n.t("admin.common.next_action"))
    expect(rendered_content).to include(I18n.t("admin.runs.validation_issues.aria",
      state: I18n.t("admin.runs.validation_issues.states.warning")))
    expect(rendered_content).to include(">#{I18n.t("admin.runs.validation_issues.states.warning")}<")
  end

  it "renders error state issues with severity labels" do
    diagnostic = {
      what_happened: "Validacion fallo",
      impact: "Datos no confiables",
      next_action: "Corregir input"
    }
    issues = [
      {
        source: "ingest.alpha",
        field: "riskModel",
        message: "Invalid risk model",
        occurred_at: "2026-03-13T10:00:00Z",
        correlation_id: "abc-123",
        severity: "error"
      }
    ]

    render_inline(described_class.new(
      title: "Diagnostico de validacion",
      state: :error,
      diagnostic: diagnostic,
      issues: issues
    ))

    expect(rendered_content).to include("validation-issues-panel--error")
    expect(rendered_content).to include(I18n.t("admin.runs.validation_issues.table_aria"))
    expect(rendered_content).to include(I18n.t("admin.runs.validation_issues.columns.severity"))
    expect(rendered_content).to include(
      I18n.t(
        "admin.runs.validation_issues.severity_aria",
        severity: I18n.t("admin.runs.validation_issues.severity.error")
      )
    )
    expect(rendered_content).to include("validation-issues-panel__table-container")
    expect(rendered_content).to include('tabindex="0"')
  end
end
