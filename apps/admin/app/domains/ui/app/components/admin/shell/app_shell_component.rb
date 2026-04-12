module Admin
  module Shell
    class AppShellComponent < ViewComponent::Base
      ICON_FILES = {
        "overview" => "layout-dashboard.svg",
        "layout-dashboard" => "layout-dashboard.svg",
        "history" => "dollar-sign.svg",
        "fx-rates" => "dollar-sign.svg",
        "dollar" => "dollar-sign.svg",
        "dollar-sign" => "dollar-sign.svg",
        "runs" => "heart-pulse.svg",
        "health" => "heart-pulse.svg",
        "heart-pulse" => "heart-pulse.svg",
        "support" => "wrench.svg",
        "wrench" => "wrench.svg",
        "default" => "layout-dashboard.svg"
      }.freeze

      FALLBACK_PATHS = [
        "M4 12h16",
        "M12 4v16"
      ].freeze

      def initialize(sidebar_items:, breadcrumb:, environment:, primary_action:, secondary_action: nil,
        topbar_links: [], presence_email: nil, sidebar_panels: nil)
        @sidebar_items = sidebar_items
        @breadcrumb = breadcrumb
        @environment = environment
        @primary_action = primary_action
        @secondary_action = secondary_action
        @topbar_links = topbar_links
        @presence_email = presence_email.to_s.presence || "ops@example.com"
        @sidebar_panels = sidebar_panels
      end

      def icon_svg_for(item_or_label)
        label = item_or_label.is_a?(Hash) ? (item_or_label[:icon_key] || item_or_label[:label]) : item_or_label
        icon_key = icon_key_for(label)
        svg_markup = svg_markup_for(icon_key)
        return helpers.raw(svg_markup) if svg_markup.present?

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
          helpers.safe_join(FALLBACK_PATHS.map { |path| helpers.tag.path(d: path) })
        end
      end

      private

      def icon_key_for(label)
        normalized = label.to_s.downcase
        return normalized if ICON_FILES.key?(normalized)
        return "layout-dashboard" if normalized.include?("overview")
        if normalized.include?("history") || normalized.include?("fx") || normalized.include?("dollar")
          return "dollar-sign"
        end
        return "heart-pulse" if normalized.include?("run") || normalized.include?("health")
        return "wrench" if normalized.include?("support")

        "default"
      end

      def svg_markup_for(icon_key)
        file_name = ICON_FILES.fetch(icon_key, ICON_FILES.fetch("default"))
        svg_path = Rails.root.join("..", "..", file_name).cleanpath
        return nil unless File.exist?(svg_path)

        normalize_svg(File.read(svg_path))
      end

      def normalize_svg(svg_markup)
        sanitized = svg_markup.dup
        sanitized.sub!(/<svg\b[^>]*>/) do |match|
          updated = match.sub(/<svg\b/, '<svg class="app-shell__nav-icon-svg" aria-hidden="true"')
          updated.gsub(/\s(width|height)="[^"]*"/, "")
        end
        sanitized.gsub!(/\sstroke="[^"]*"/, ' stroke="currentColor"')
        sanitized.gsub!(/\sstyle="[^"]*"/, "")
        sanitized
      end
    end
  end
end
