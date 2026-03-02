require "rails_helper"

RSpec.describe "Admin component comparison", type: :request do
  it "renders both ViewComponent and Phlex cards" do
    get "/admin/component-comparison"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Component Comparison: ViewComponent vs Phlex")
    expect(response.body).to include("ViewComponent")
    expect(response.body).to include("Phlex")
    expect(response.body).to include("Success rate (last 50)")
  end
end
