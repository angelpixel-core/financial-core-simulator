# frozen_string_literal: true

module FCS
  module Ports
    class AuthzContext
      def call(account:, role:, required_role:, gate:, token_key: nil)
        raise NotImplementedError, "#{self.class} must implement #call"
      end
    end
  end
end
