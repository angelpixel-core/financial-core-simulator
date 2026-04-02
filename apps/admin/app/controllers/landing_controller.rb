class LandingController < ApplicationController
  layout 'landing'

  def index
    @demo_path = '/admin/login'
    @documentation_url = 'https://docs.ruby-lang.org'
    @source_url = 'https://github.com'
  end
end
