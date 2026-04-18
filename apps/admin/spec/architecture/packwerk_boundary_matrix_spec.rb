require "rails_helper"
require "yaml"

RSpec.describe "Packwerk boundary matrix" do
  let(:expected_dependencies) do
    {
      "access_control" => %w[auth core events],
      "artifacts" => %w[auth],
      "auth" => %w[access_control core],
      "core" => [],
      "dashboard" => %w[demo fx runs ui validation],
      "demo" => %w[core fx runs],
      "events" => %w[core],
      "fx" => %w[core demo runs],
      "observability" => %w[core],
      "release" => [],
      "runs" => %w[artifacts core dashboard events fx observability validation],
      "ui" => %w[auth],
      "validation" => []
    }
  end

  it "keeps package dependencies aligned with the approved context matrix" do
    expected_dependencies.each do |domain, expected|
      package = Rails.root.join("app/domains/#{domain}/package.yml")
      yaml = YAML.load_file(package)
      actual = Array(yaml["dependencies"]).map { |entry| entry.split("/").last }.sort

      expect(actual).to eq(expected.sort), "Expected #{domain} dependencies to be #{expected.sort}, got #{actual}"
    end
  end
end
