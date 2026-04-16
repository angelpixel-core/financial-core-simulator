require 'rails_helper'
require 'yaml'

RSpec.describe 'Packwerk boundary matrix' do
  MATRIX_ROOT = Rails.root

  EXPECTED_DEPENDENCIES = {
    'access_control' => %w[auth core events],
    'artifacts' => %w[auth],
    'auth' => %w[access_control core],
    'core' => [],
    'dashboard' => %w[demo fx runs ui validation],
    'demo' => %w[core fx runs],
    'events' => %w[core],
    'fx' => %w[core demo runs],
    'observability' => %w[core],
    'release' => [],
    'runs' => %w[artifacts core dashboard events fx observability validation],
    'ui' => %w[auth],
    'validation' => []
  }.freeze

  it 'keeps package dependencies aligned with the approved context matrix' do
    EXPECTED_DEPENDENCIES.each do |domain, expected|
      package = MATRIX_ROOT.join("app/domains/#{domain}/package.yml")
      yaml = YAML.load_file(package)
      actual = Array(yaml['dependencies']).map { |entry| entry.split('/').last }.sort

      expect(actual).to eq(expected.sort), "Expected #{domain} dependencies to be #{expected.sort}, got #{actual}"
    end
  end
end
