# frozen_string_literal: true

module FCS
  module Ports
    class RunRepository
      def save_run!(_run_attributes)
        raise NotImplementedError, "#{self.class} must implement #save_run!"
      end

      def find_run(_run_id)
        raise NotImplementedError, "#{self.class} must implement #find_run"
      end
    end
  end
end
