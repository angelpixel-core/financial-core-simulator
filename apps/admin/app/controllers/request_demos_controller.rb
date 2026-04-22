# frozen_string_literal: true

class RequestDemosController < ApplicationController
  layout "landing"

  def new
    @demo_request = DemoRequest.new(preferred_contact: "video_call")
  end

  def create
    @demo_request = DemoRequest.new(demo_request_params)

    if @demo_request.save
      redirect_to request_demo_success_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def success
  end

  private

  def demo_request_params
    params.require(:demo_request).permit(:name, :email, :company, :message, :preferred_contact)
  end
end
