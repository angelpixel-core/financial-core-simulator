require 'rails_helper'

RSpec.describe 'Dashboard financial overview', type: :request do
  it 'returns financial overview payload for valid run' do
    run = Run.create!(status: :succeeded, input_json: {
                        'trades' => [
                          { 'timestamp' => '2026-03-29T12:00:00Z', 'quantity' => 2, 'price' => 10, 'symbol' => 'BTC-USD' }
                        ]
                      })

    get "/dashboard/financial-overview/#{run.id}", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed.fetch('contractVersion')).to eq('v1')
    overview = parsed.fetch('financial_overview')
    expect(overview.fetch('trade_activity')).to be_a(Array)
    expect(overview.fetch('trade_volume')).to be_a(Array)
  end

  it 'returns not found for missing run' do
    get '/dashboard/financial-overview/999999', as: :json

    expect(response).to have_http_status(:not_found)
  end
end
