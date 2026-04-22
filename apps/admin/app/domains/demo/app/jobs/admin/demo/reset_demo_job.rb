# frozen_string_literal: true

module Admin
  module Demo
    class ResetDemoJob < ApplicationJob
      queue_as :default

      def perform(trigger: "recurring")
        Admin::Demo::Sandbox::Reset.new.call(trigger: trigger)
      end
    end
  end
end
