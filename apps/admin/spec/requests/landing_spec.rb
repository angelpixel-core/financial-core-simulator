require 'rails_helper'

RSpec.describe 'Public landing', type: :request do
  it 'renders public root landing content' do
    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Deterministic Financial Processing.')
    expect(response.body).to include('Always the same input. Always the same output.')
    expect(response.body).to include('View Demo')
    expect(response.body).to include('id="why"')
    expect(response.body).to include('id="how"')
    expect(response.body).to include('id="features"')
    expect(response.body).to include('id="architecture"')
    expect(response.body).to include('id="faq"')
  end

  it 'keeps root publicly reachable when ADMIN_UI_TOKEN is configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ADMIN_UI_TOKEN').and_return('ui-secret')

    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Deterministic Financial Engine')
  end

  it 'exposes CTA links to admin login and source/doc destinations' do
    get '/'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/admin/login"')
    expect(response.body).to include('href="https://github.com/angelpixel-core/financial-core-simulator"')
    expect(response.body).to include('View source')
  end
end
