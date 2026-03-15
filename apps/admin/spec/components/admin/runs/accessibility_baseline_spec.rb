require "rails_helper"

RSpec.describe "Run diagnostics accessibility baseline" do
  it "defines visible focus styles for interactive elements in app shell" do
    css = File.read(Rails.root.join("app/assets/stylesheets/application.css"))

    expect(css).to include(".app-shell a:focus-visible")
    expect(css).to include("outline: 2px solid #0d9488;")
  end
end
