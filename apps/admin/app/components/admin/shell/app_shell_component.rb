module Admin
  module Shell
    class AppShellComponent < ViewComponent::Base
      ICON_PATHS = {
        "overview" => [
          "M3 12h8V3H3z",
          "M13 21h8v-6h-8z",
          "M13 10h8V3h-8z",
          "M3 21h8v-7H3z"
        ],
        "runs" => [
          "M5 4h10l4 4v12H5z",
          "M15 4v4h4",
          "M9 13h6",
          "M9 17h6"
        ],
        "validation" => [
          "M12 3l8 4v6c0 5-3.5 8-8 8s-8-3-8-8V7z",
          "M9 12l2 2 4-4"
        ],
        "artifacts" => [
          "M4 4h16v16H4z",
          "M8 8h8",
          "M8 12h8",
          "M8 16h5"
        ],
        "default" => [
          "M4 12h16",
          "M12 4v16"
        ]
      }.freeze

      def initialize(sidebar_items:, breadcrumb:, environment:, primary_action:, secondary_action: nil, topbar_links: [])
        @sidebar_items = sidebar_items
        @breadcrumb = breadcrumb
        @environment = environment
        @primary_action = primary_action
        @secondary_action = secondary_action
        @topbar_links = topbar_links
      end

      def icon_svg_for(label)
        paths = ICON_PATHS.fetch(icon_key_for(label), ICON_PATHS.fetch("default"))

        helpers.tag.svg(
          class: "app-shell__nav-icon-svg",
          viewBox: "0 0 24 24",
          fill: "none",
          stroke: "currentColor",
          "stroke-width": "1.8",
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "aria-hidden": "true"
        ) do
          helpers.safe_join(paths.map { |path| helpers.tag.path(d: path) })
        end
      end

      private

      def icon_key_for(label)
        normalized = label.to_s.downcase
        return "overview" if normalized.include?("overview")
        return "runs" if normalized.include?("run")
        return "validation" if normalized.include?("validation")
        return "artifacts" if normalized.include?("artifact")

        "default"
      end
    end
  end
end
