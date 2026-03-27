module Admin
  module Runs
    class RunReliabilityBannerComponent < ViewComponent::Base
      def initialize(state:, title:, diagnostic:)
        @state = state.to_sym
        @title = title
        @diagnostic = diagnostic
      end

      def state_class
        case @state
        when :reliable
          "run-reliability-banner--reliable"
        when :degraded
          "run-reliability-banner--degraded"
        when :loading
          "run-reliability-banner--loading"
        else
          "run-reliability-banner--info"
        end
      end

      def state_label
        case @state
        when :reliable
          I18n.t("admin.runs.reliability_banner.states.reliable")
        when :degraded
          I18n.t("admin.runs.reliability_banner.states.degraded")
        when :loading
          I18n.t("admin.runs.reliability_banner.states.loading")
        else
          I18n.t("admin.runs.reliability_banner.states.info")
        end
      end

      def state_icon
        case @state
        when :reliable
          "OK"
        when :degraded
          "!"
        when :loading
          "..."
        else
          "i"
        end
      end
    end
  end
end
