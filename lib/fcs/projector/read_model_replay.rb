module FCS
  module Projector
    # Replays event streams into read models.
    class ReadModelReplay
      def initialize(
        today: Date.today,
        projection_store: nil,
        projection_store_factory: nil,
        event_projection_router: FCS::Projector::EventProjectionRouter.new
      )
        @today = today
        @projection_store_factory = projection_store_factory ||
                                    FCS::Projector::DefaultProjectionStoreFactory.new(today: @today)
        @event_projection_router = event_projection_router

        validate_projection_store_factory_interface!(@projection_store_factory)
        validate_event_projection_router_interface!(@event_projection_router)

        @projection_store = projection_store || build_projection_store

        validate_projection_store_interface!(@projection_store)
      end

      def apply_stream!(stream)
        validate_stream_shape!(stream)

        stream.each { |event| apply_event!(event) }
        read_model
      end

      def rebuild_from_stream!(stream)
        self.class.new(
          today: @today,
          projection_store_factory: @projection_store_factory,
          event_projection_router: @event_projection_router
        ).apply_stream!(stream)
      end

      delegate :read_model, to: :projection_store

      private

      attr_reader :projection_store, :projection_store_factory, :event_projection_router

      def apply_event!(event)
        validate_event_shape!(event)

        event_type = event.fetch("eventType", nil)
        projection_keys = event_projection_router.projections_for(event_type)
        if projection_keys.nil? || projection_keys.empty?
          raise_invalid!("unsupported replay event type", field: "event.eventType")
        end

        projection_store.apply!(projection_keys, event)
      end

      def validate_stream_shape!(stream)
        return if stream.is_a?(Array)

        raise_invalid!("replay stream must be an array", field: "stream")
      end

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!("replay event must be an object", field: "event")
      end

      def build_projection_store
        store = projection_store_factory.call
        validate_projection_store_interface!(store)
        store
      end

      def validate_projection_store_interface!(store)
        return if store.respond_to?(:apply!) && store.respond_to?(:read_model)

        raise_invalid!("projection store must implement apply! and read_model", field: "projectionStore")
      end

      def validate_projection_store_factory_interface!(factory)
        return if factory.respond_to?(:call)

        raise_invalid!("projection store factory must implement call", field: "projectionStoreFactory")
      end

      def validate_event_projection_router_interface!(router)
        return if router.respond_to?(:projections_for)

        raise_invalid!("event projection router must implement projections_for", field: "eventProjectionRouter")
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
