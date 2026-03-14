require "rails_helper"
require "view_component/test_helpers"

RSpec.describe Admin::Runs::RunReliabilityBannerComponent, type: :component do
  include ViewComponent::TestHelpers

  it "renders diagnostic guidance for degraded state" do
    diagnostic = {
      what_happened: "No hay un run confiable verificado",
      impact: "La inspeccion inicia en modo degradado",
      next_action: "Ejecuta verificacion de hash en el ultimo run"
    }

    render_inline(described_class.new(
      state: :degraded,
      title: "Reliability status",
      diagnostic: diagnostic
    ))

    expect(rendered_content).to include("No hay un run confiable verificado")
    expect(rendered_content).to include("Impacto")
    expect(rendered_content).to include("Siguiente accion")
    expect(rendered_content).to include("role=\"status\"")
    expect(rendered_content).to include("aria-live=\"polite\"")
  end

  it "renders a reliable state banner" do
    diagnostic = {
      what_happened: "Run verificado",
      impact: "Todo ok",
      next_action: "Continuar"
    }

    render_inline(described_class.new(
      state: :reliable,
      title: "Reliability status",
      diagnostic: diagnostic
    ))

    expect(rendered_content).to include("run-reliability-banner--reliable")
  end

  it "renders a loading state banner" do
    diagnostic = {
      what_happened: "Cargando",
      impact: "Esperando datos",
      next_action: "Reintenta"
    }

    render_inline(described_class.new(
      state: :loading,
      title: "Reliability status",
      diagnostic: diagnostic
    ))

    expect(rendered_content).to include("run-reliability-banner--loading")
  end
end
