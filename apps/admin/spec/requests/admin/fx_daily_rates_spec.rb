require 'rails_helper'

RSpec.describe 'Admin FX daily rates', type: :request do
  let(:headers) { { 'X-Admin-User' => 'alice', 'X-Admin-Role' => 'operator' } }

  around do |example|
    travel_to(Time.zone.parse('2026-03-30 10:00:00')) { example.run }
  end

  it 'creates a manual daily rate' do
    post admin_fx_daily_rates_path,
         params: {
           operational_date: '2026-03-30',
           base_currency: 'USD',
           quote_currency: 'ARS',
           rate: '1000.5'
         },
         headers: headers

    expect(response).to have_http_status(:found)
    expect(FxDailyRate.count).to eq(1)
    expect(FxDailyRate.first.source).to eq('manual')
  end

  it 'carries forward a prior rate' do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 29),
      base_currency: 'USD',
      quote_currency: 'ARS',
      rate: '999.5',
      source: 'manual'
    )

    post carry_forward_admin_fx_daily_rates_path,
         params: {
           operational_date: '2026-03-30',
           base_currency: 'USD',
           quote_currency: 'ARS'
         },
         headers: headers

    expect(response).to have_http_status(:found)
    expect(FxDailyRate.count).to eq(2)
    expect(FxDailyRate.order(:created_at).last.source).to eq('carry_forward')
  end
end
