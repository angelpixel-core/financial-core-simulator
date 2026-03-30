require 'rails_helper'

RSpec.describe 'Admin reporting settings', type: :request do
  let(:headers) { { 'X-Admin-User' => 'alice', 'X-Admin-Role' => 'operator' } }

  it 'updates reporting currency' do
    patch admin_fx_reporting_settings_path,
          params: { reporting_currency: 'ARS' },
          headers: headers

    expect(response).to have_http_status(:found)
    expect(ReportingSetting.current.reporting_currency).to eq('ARS')
  end
end
