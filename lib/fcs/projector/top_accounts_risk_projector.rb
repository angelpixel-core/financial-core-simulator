require 'bigdecimal'
require 'time'

module FCS
  module Projector
    class TopAccountsRiskProjector
      ACCOUNT_TOTALS_EVENT_TYPE = 'ACCOUNT_TOTALS_NORMALIZED'.freeze
      RISK_SNAPSHOT_EVENT_TYPE = 'RISK_SNAPSHOT_NORMALIZED'.freeze
      SUPPORTED_EVENT_TYPES = [ACCOUNT_TOTALS_EVENT_TYPE, RISK_SNAPSHOT_EVENT_TYPE].freeze

      def initialize
        @top_accounts_by_id = {}
        @risk_view_by_id = {}
        @top_accounts_occurred_at = {}
        @risk_view_occurred_at = {}
      end

      def apply!(event)
        validate_event_shape!(event)

        event_type = event.fetch('eventType', nil)
        validate_event_type!(event_type)

        occurred_at_value = event.fetch('occurredAt')
        occurred_at = parse_occurred_at!(occurred_at_value)

        if event_type == ACCOUNT_TOTALS_EVENT_TYPE
          apply_account_totals!(event, occurred_at, occurred_at_value)
        else
          apply_risk_snapshot!(event, occurred_at, occurred_at_value)
        end

        true
      end

      def read_model
        {
          'topAccounts' => sorted_top_accounts,
          'riskView' => @risk_view_by_id
        }
      end

      private

      def apply_account_totals!(event, occurred_at, occurred_at_value)
        payload = event.fetch('payload')
        account_id = payload.fetch('accountId')

        validate_non_empty_string!(account_id, field: 'event.payload.accountId')

        previous = @top_accounts_occurred_at[account_id]
        return if previous && occurred_at < previous

        @top_accounts_occurred_at[account_id] = occurred_at
        @top_accounts_by_id[account_id] = {
          'accountId' => account_id,
          'totalPnLQuote' => payload.fetch('totalPnLQuote').to_s,
          'realizedNetPnLQuote' => payload.fetch('realizedNetPnLQuote').to_s,
          'unrealizedPnLQuote' => payload.fetch('unrealizedPnLQuote').to_s,
          'correlationId' => event.fetch('correlationId').to_s,
          'occurredAt' => occurred_at_value
        }
      end

      def apply_risk_snapshot!(event, occurred_at, occurred_at_value)
        payload = event.fetch('payload')
        account_id = payload.fetch('accountId')

        validate_non_empty_string!(account_id, field: 'event.payload.accountId')

        previous = @risk_view_occurred_at[account_id]
        return if previous && occurred_at < previous

        @risk_view_occurred_at[account_id] = occurred_at
        @risk_view_by_id[account_id] = {
          'accountId' => account_id,
          'status' => payload.fetch('status').to_s,
          'marginRatio' => payload.fetch('marginRatio').to_s,
          'correlationId' => event.fetch('correlationId').to_s,
          'occurredAt' => occurred_at_value
        }
      end

      def sorted_top_accounts
        @top_accounts_by_id
          .values
          .sort_by { |row| -decimal_value(row.fetch('totalPnLQuote')) }
      end

      def decimal_value(value)
        BigDecimal(value.to_s)
      rescue ArgumentError
        BigDecimal('0')
      end

      def validate_event_shape!(event)
        return if event.is_a?(Hash)

        raise_invalid!('projector event must be an object', field: 'event')
      end

      def validate_event_type!(event_type)
        return if SUPPORTED_EVENT_TYPES.include?(event_type)

        raise_invalid!('unsupported projector event type', field: 'event.eventType')
      end

      def validate_non_empty_string!(value, field:)
        return if value.is_a?(String) && !value.strip.empty?

        raise_invalid!('projector field must be a non-empty string', field: field)
      end

      def parse_occurred_at!(occurred_at)
        validate_non_empty_string!(occurred_at, field: 'event.occurredAt')
        Time.iso8601(occurred_at)
      rescue ArgumentError
        raise_invalid!('projector occurredAt must be ISO8601', field: 'event.occurredAt')
      end

      def raise_invalid!(message, field:)
        raise FCS::Error.new(FCS::Errors::ERR_VALIDATION, message, details: { field: field })
      end
    end
  end
end
