# frozen_string_literal: true

module FCS
  module Application
    module Base
      class Publisher
        def initialize(enabled: true)
          @enabled = enabled
        end

        def enabled?
          @enabled
        end

        def publish(event:)
          return Result.success(data: {published: false, event_type: event[:event_type]}) unless enabled?

          raise NotImplementedError, "publish must be implemented"
        end
      end

      class NoopPublisher < Publisher
        def publish(event:)
          Result.success(data: {published: false, event_type: event[:event_type]})
        end
      end
    end
  end
end
