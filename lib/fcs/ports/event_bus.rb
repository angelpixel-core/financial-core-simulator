# frozen_string_literal: true

module FCS
  module Ports
    class EventBus
      def publish(_event_name, _payload = {})
        raise NotImplementedError, "#{self.class} must implement #publish"
      end
    end
  end
end
