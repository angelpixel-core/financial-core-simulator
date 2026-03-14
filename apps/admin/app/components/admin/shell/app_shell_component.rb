module Admin
  module Shell
    class AppShellComponent < ViewComponent::Base
      def initialize(sidebar_items:, breadcrumb:, environment:, primary_action:, secondary_action: nil, topbar_links: [])
        @sidebar_items = sidebar_items
        @breadcrumb = breadcrumb
        @environment = environment
        @primary_action = primary_action
        @secondary_action = secondary_action
        @topbar_links = topbar_links
      end
    end
  end
end
