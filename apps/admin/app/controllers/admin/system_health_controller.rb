class Admin::SystemHealthController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :load_navigation_context

  def show
    @metrics = Admin::Dashboard::ReadMetrics.new.call
  end

  private

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
