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
    end
  end
end
