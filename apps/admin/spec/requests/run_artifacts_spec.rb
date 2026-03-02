require "rails_helper"
require "fileutils"
require "json"
require "tmpdir"

RSpec.describe "Run artifacts", type: :request do
  it "serves result.json when artifact path is under storage/runs" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("result.json")
    File.write(path, JSON.generate({ ok: true }))

    run = Run.create!(
      input_json: { "schemaVersion" => "1.0" },
      artifacts: { "result_json_path" => path.to_s }
    )

    get "/runs/#{run.id}/result"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq({ "ok" => true })
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "returns not_found when artifact path is outside storage/runs" do
    run = Run.create!(input_json: { "schemaVersion" => "1.0" })

    Dir.mktmpdir do |dir|
      outside_path = File.join(dir, "result.json")
      File.write(outside_path, JSON.generate({ leaked: true }))
      run.update!(artifacts: { "result_json_path" => outside_path })

      get "/runs/#{run.id}/result"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Artifact not found")
    end
  end
end
