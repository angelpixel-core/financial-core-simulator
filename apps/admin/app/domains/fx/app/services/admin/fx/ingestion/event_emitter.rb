# frozen_string_literal: true

module Admin
  module Fx
    module Ingestion
      class EventEmitter
        def initialize(result_class: Result, event_class: FCS::Application::Base::Event,
          publisher: FCS::Application::Base::NoopPublisher.new, publish_enabled: true)
          @result_class = result_class
          @event_class = event_class
          @publisher = publisher
          @publish_enabled = publish_enabled
        end

        def emit(event_type:, data: {}, metadata: {})
          event = event_class.new(event_type: event_type, data: data, metadata: metadata)
          record = FxRateEvent.create!(event.to_h)
          publish_result = if publish_enabled?
            publisher.publish(event: event.to_h)
          else
            FCS::Application::Base::Result.success(
              data: {published: false, event_type: event.event_type}
            )
          end

          result_class.success(
            data: {event_id: record.event_id},
            metadata: {event_type: event.event_type, publish_result: publish_result.to_h}
          )
        rescue ArgumentError => e
          result_class.failure(error_code: "event_invalid", context: {message: e.message, event_type: event_type})
        rescue => e
          result_class.failure(error_code: "event_persist_failed",
            context: {message: e.message, event_type: event_type})
        end

        def emit_ingestion(event_type:, ingestion:, source:, data: {}, error: {}, metadata: {})
          emit(
            event_type: event_type,
            data: standard_data(data: data, error: error, source: source),
            metadata: standard_metadata(metadata: metadata, ingestion: ingestion)
          )
        end

        private

        def publish_enabled?
          @publish_enabled
        end

        attr_reader :result_class, :event_class, :publisher

        def standard_data(data:, error:, source:)
          base = {
            source_id: source.id,
            source_code: source.code
          }
          base.merge(data).merge(error)
        end

        def standard_metadata(metadata:, ingestion:)
          {
            correlation_id: ingestion.correlation_id,
            causation_id: ingestion.causation_id,
            source_id: ingestion.source_id,
            ingestion_id: ingestion.id
          }.merge(metadata)
        end
      end
    end
  end
end
