require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::ValidationIssuesPanelComponent, type: :component do
  include ViewComponent::TestHelpers

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
    expect(rendered_content).to include("Sin issues de validacion reportados")
    expect(rendered_content).to include("Estado de validacion")
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
    expect(rendered_content).to include("Que paso")
    expect(rendered_content).to include("Impacto")
    expect(rendered_content).to include("Siguiente accion")
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
    expect(rendered_content).to include("Issues de validacion")
    expect(rendered_content).to include("Severidad")
    expect(rendered_content).to include("Severidad: Error")
  end
end
