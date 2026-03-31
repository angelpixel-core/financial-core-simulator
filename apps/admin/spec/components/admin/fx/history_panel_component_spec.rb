require 'rails_helper'
require 'view_component/test_helpers'

RSpec.describe Admin::Fx::HistoryPanelComponent, type: :component do
  include ViewComponent::TestHelpers

  it 'shows edit and delete actions for operators' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '100',
      source: 'manual'
    )

    placeholder = FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: nil,
      source: 'placeholder'
    )

    FxRateGap.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: 'USD',
      quote_currency: 'ARS',
      status: 'open',
      placeholder_rate: placeholder
    )

    render_inline(described_class.new(base_currency: 'USD', quote_currency: 'ARS', role: 'operator'))

    expect(rendered_content).to include('Edit')
    expect(rendered_content).to include('Delete')
    expect(rendered_content).to include('Open gap')
  end

  it 'hides actions for viewers' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '100',
      source: 'manual'
    )

    render_inline(described_class.new(base_currency: 'USD', quote_currency: 'ARS', role: 'viewer'))

    expect(rendered_content).not_to include('Edit')
    expect(rendered_content).not_to include('Delete')
  end
end
