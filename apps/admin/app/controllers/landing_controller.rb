class LandingController < ApplicationController
  layout 'landing'

  def index
    @demo_path = '/admin/login'
    @source_url = 'https://github.com/angelpixel-core/financial-core-simulator'
  end
end
