# frozen_string_literal: true

module Admin
  module AccessControl
    class AuthzContextAdapter < FCS::Ports::AuthzContext
      def initialize(request:)
        @request = request
      end

      def call(account:, role:, required_role:, gate:, token_key: nil)
        {
          account_id: account&.id&.to_s,
          account_email: account&.email.to_s.presence,
          role: role.to_s,
          required_role: required_role.to_s,
          gate: gate.to_s,
          token_key: token_key,
          path: value_for(:path),
          method: value_for(:request_method),
          ip: value_for(:remote_ip),
          request_id: value_for(:request_id)
        }.compact
      end

      private

      def value_for(method_name)
        return nil unless @request.respond_to?(method_name)

        @request.public_send(method_name).to_s.presence
      end
    end
  end
end
