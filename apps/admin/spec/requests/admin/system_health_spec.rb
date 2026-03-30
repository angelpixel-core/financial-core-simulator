require 'rails_helper'

RSpec.describe 'Admin system health', type: :request do
  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  it 'renders system health for viewer session' do
    get '/admin/system-health', headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t('nav.runs', locale: :en))
  end

  def admin_session_headers
    { 'X-Admin-User' => 'alice', 'X-Admin-Role' => 'viewer' }
  end
end
