class ApplicationController < ActionController::Base
  include Rodauth::Rails::ControllerMethods
  include AdminShellHelper

  helper_method :current_admin_account, :admin_shell_account_email

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
