# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec", "fixtures", "vcr_cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  config.filter_sensitive_data("<BCRA_BASE_URL>") do |interaction|
    uri = URI(interaction.request.uri)
    "#{uri.scheme}://#{uri.host}"
  end
end
