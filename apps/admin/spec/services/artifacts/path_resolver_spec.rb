require "rails_helper"
require "fileutils"

RSpec.describe Artifacts::PathResolver do
  it "returns path when artifact is inside storage/runs" do
    base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
    FileUtils.mkdir_p(base_dir)
    path = base_dir.join("resolver-ok.json")
    File.write(path, "{}")

    run = Run.create!(
      status: :succeeded,
      input_json: {"schemaVersion" => "1.0"},
      artifacts: {"result_json_path" => path.to_s}
    )

    resolved = described_class.new(run: run, attribute: :result_json_path).call

    expect(resolved).to eq(File.expand_path(path))
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  it "returns nil when artifact is outside storage/runs" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    Dir.mktmpdir do |dir|
      outside_path = File.join(dir, "resolver-outside.json")
      File.write(outside_path, "{}")
      run.update!(artifacts: {"result_json_path" => outside_path})

      resolved = described_class.new(run: run, attribute: :result_json_path).call

      expect(resolved).to be_nil
    end
  end

  it "returns nil when artifact path is a symlink escaping storage/runs" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})

    Dir.mktmpdir do |outside_dir|
      outside_path = File.join(outside_dir, "resolver-link-target.json")
      File.write(outside_path, "{}")

      base_dir = Rails.root.join("storage", "runs", "spec_artifacts")
      FileUtils.mkdir_p(base_dir)
      symlink_path = base_dir.join("resolver-link.json")
      FileUtils.ln_s(outside_path, symlink_path, force: true)
      run.update!(artifacts: {"result_json_path" => symlink_path.to_s})

      resolved = described_class.new(run: run, attribute: :result_json_path).call

      expect(resolved).to be_nil
    ensure
      FileUtils.rm_f(symlink_path) if defined?(symlink_path)
    end
  end
end
