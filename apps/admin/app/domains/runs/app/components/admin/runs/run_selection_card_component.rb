module Admin
  module Runs
    class RunSelectionCardComponent < ViewComponent::Base
      def initialize(run:, title:, cta_label:, cta_path:, highlight: false)
        @run = run
        @title = title
        @cta_label = cta_label
        @cta_path = cta_path
        @highlight = highlight
      end

      def status_label
        @run.status.to_s.tr("_", " ")
      end

      def verification_label
        @run.verification_status.to_s.tr("_", " ")
      end

      def created_at_label
        @run.created_at.utc.strftime("%Y-%m-%d %H:%M UTC")
      end

      def duration_label
        return "N/A" if @run.duration_ms.nil?

        "#{@run.duration_ms} ms"
      end

      def card_classes
        classes = ["run-selection-card"]
        classes << "run-selection-card--highlight" if @highlight
        classes.join(" ")
      end
    end
  end
end
