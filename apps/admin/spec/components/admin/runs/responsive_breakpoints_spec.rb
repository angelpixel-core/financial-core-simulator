require "rails_helper"

RSpec.describe "Run diagnostics responsive breakpoints" do
  it "declares explicit mobile, tablet, and desktop ranges in stylesheet" do
    css = File.read(Rails.root.join("app/assets/stylesheets/application.css"))

    expect(css).to include("@media (max-width: 767px)")
    expect(css).to include("@media (min-width: 768px) and (max-width: 1023px)")
    expect(css).to include("@media (max-width: 1024px)")
  end
end
