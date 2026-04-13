# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec", "fixtures", "vcr_cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  config.ignore_request do |request|
    uri = URI(request.uri.to_s)
    ["localhost", "127.0.0.1"].include?(uri.host)
  end
end
