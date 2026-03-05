require "rails_helper"

RSpec.describe "admin_ui_token_guard initializer" do
  let(:initializer_path) { Rails.root.join("config/initializers/admin_ui_token_guard.rb") }
  let(:production_env) { ActiveSupport::StringInquirer.new("production") }

  around do |example|
    previous = ENV["ADMIN_UI_TOKEN"]
    example.run
    ENV["ADMIN_UI_TOKEN"] = previous
  end

  it "boots in production when ADMIN_UI_TOKEN is non-empty" do
    allow(Rails).to receive(:env).and_return(production_env)
    ENV["ADMIN_UI_TOKEN"] = "ui-secret"

    expect { load initializer_path }.not_to raise_error
  end

  it "fails fast in production when ADMIN_UI_TOKEN is missing" do
    allow(Rails).to receive(:env).and_return(production_env)
    ENV["ADMIN_UI_TOKEN"] = nil

    expect { load initializer_path }.to raise_error(RuntimeError, /ADMIN_UI_TOKEN/)
  end

  it "fails fast in production when ADMIN_UI_TOKEN is blank" do
    allow(Rails).to receive(:env).and_return(production_env)
    ENV["ADMIN_UI_TOKEN"] = "   "

    expect { load initializer_path }.to raise_error(RuntimeError, /ADMIN_UI_TOKEN/)
  end
end
