require 'rails_helper'
require 'fileutils'
require 'nokogiri'

RSpec.describe 'Admin keyboard navigation flow', type: :request do
  it 'supports state-first navigation from overview to health and docs' do
    base_dir = Rails.root.join('storage', 'runs', 'spec_keyboard_flow')
    FileUtils.mkdir_p(base_dir)
    result_path = base_dir.join('result.json')
    File.write(result_path, '{"accounts":[]}')

    run = Run.create!(
      status: :succeeded,
      verification_status: :verified,
      input_hash: 'hash-keyboard',
      artifacts: { 'result_json_path' => result_path.to_s }
    )

    context = {
      selected_run: run.id,
      run_status: 'succeeded',
      validation_status: 'verified',
      date_range: 'last_7d',
      correlation_id: 'corr-kbd'
    }

    get '/admin/overview', params: context, headers: admin_session_headers
    expect(response).to have_http_status(:ok)

    doc = Nokogiri::HTML(response.body)
    nav = doc.at_css('.app-shell__nav')
    links = nav.css('a')

    labels = links.map { |link| link.text.strip }
    expected_labels = ['Overview', 'FX Rates', 'Health', 'Docs']
    ordered_labels = labels.select { |label| expected_labels.include?(label) }
    expect(ordered_labels).to eq(expected_labels)
    expect(labels).not_to include('Support', 'Validation', 'Artifacts')

    overview_link = links.find { |node| node.text.strip == 'Overview' }
    health_link = links.find { |node| node.text.strip == 'Health' }
    docs_link = links.find { |node| node.text.strip == 'Docs' }

    expect(overview_link['aria-current'].delete('"')).to eq('page')

    expect(overview_link['href']).to start_with('/admin/overview')
    expect(health_link['href']).to start_with('/admin/system-health')
    expect(docs_link['href']).to start_with('/admin/docs')

    get health_link['href'], headers: admin_session_headers
    expect(response).to have_http_status(:ok)

    expect(response.body).to include(I18n.t('admin.overview.validation.title'))

    get docs_link['href'], params: context, headers: admin_session_headers
    expect(response).to have_http_status(:ok)
  ensure
    FileUtils.rm_f(result_path) if defined?(result_path)
  end

  def admin_session_headers
    { 'X-Admin-User' => 'alice', 'X-Admin-Role' => 'admin' }
  end
end
