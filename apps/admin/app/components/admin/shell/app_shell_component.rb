module Admin
  module Shell
    class AppShellComponent < ViewComponent::Base
      def initialize(sidebar_items:, breadcrumb:, environment:, primary_action:, secondary_action: nil)
        @sidebar_items = sidebar_items
        @breadcrumb = breadcrumb
        @environment = environment
        @primary_action = primary_action
        @secondary_action = secondary_action
      end
    end
  end
end
