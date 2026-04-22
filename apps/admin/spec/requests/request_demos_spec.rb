require "rails_helper"

RSpec.describe "Request demo", type: :request do
  describe "GET /request-demo" do
    it "renders the request form" do
      get "/request-demo"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request for Demo")
      expect(response.body).to include("Preferred demo flow")
    end
  end

  describe "POST /request-demo" do
    it "persists the request and redirects to success" do
      expect {
        post "/request-demo", params: {
          demo_request: {
            name: "Ava Rivera",
            email: "ava@example.com",
            company: "Northwind",
            preferred_contact: "video_call",
            message: "Need a walkthrough for operations and finance"
          }
        }
      }.to change(DemoRequest, :count).by(1)

      request_record = DemoRequest.order(:created_at).last
      expect(request_record).not_to be_nil
      expect(request_record.status).to eq("pending")
      expect(request_record.preferred_contact).to eq("video_call")
      expect(response).to redirect_to("/request-demo/success")
    end

    it "returns errors when required fields are missing" do
      expect {
        post "/request-demo", params: {
          demo_request: {
            name: "",
            email: "",
            company: "",
            preferred_contact: ""
          }
        }
      }.not_to change(DemoRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please review the highlighted fields.")
    end
  end

  describe "GET /request-demo/success" do
    it "renders confirmation copy" do
      get "/request-demo/success"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Thanks, we got your demo request.")
    end
  end
end
