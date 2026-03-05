module FCS
  module Projector
    class ReadModelReplay
      def initialize(today: Date.today)
        @today = today
        reset_projectors!
      end

      def apply_stream!(stream)
        validate_stream_shape!(stream)

        stream.each { |event| apply_event!(event) }
        read_model
      end

      def rebuild_from_stream!(stream)
        self.class.new(today: @today).apply_stream!(stream)
      end

      def read_model
        overview_projector
          .read_model
          .merge(trend_projector.read_model)
          .merge(top_accounts_risk_projector.read_model)
      end

      private

      attr_reader :overview_projector, :trend_projector, :top_accounts_risk_projector

      def reset_projectors!
        @overview_projector = FCS::Projector::OverviewKpiStatusMixProjector.new
        @trend_projector = FCS::Projector::TrendLatestRunProjector.new(today: @today)
        @top_accounts_risk_projector = FCS::Projector::TopAccountsRiskProjector.new
      end

      def apply_event!(event)
        validate_event_shape!(event)

        event_type = event.fetch('eventType', nil)

        if event_type == 'RUN_LIFECYCLE_NORMALIZED'
          overview_projector.apply!(event)
          trend_projector.apply!(event)
          return
        end

        if %w[ACCOUNT_TOTALS_NORMALIZED RISK_SNAPSHOT_NORMALIZED].include?(event_type)
          top_accounts_risk_projector.apply!(event)
          return
        end

        raise_invalid!('unsupported replay event type', field: 'event.eventType')
      end

      def validate_stream_shape!(stream)
        return if stream.is_a?(Array)

        raise_invalid!('replay stream must be an array', field: 'stream')
      end

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!('replay event must be an object', field: 'event')
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
