# frozen_string_literal: true

module Admin
  module Fx
    class RateCreator
      def initialize(rate_repository: Admin::Fx::Rates::Repository.new)
        @rate_repository = rate_repository
      end

      def self.call(
        operational_date:,
        base_currency:,
        quote_currency:,
        rate:,
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        new.call(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def call(
        operational_date:,
        base_currency:,
        quote_currency:,
        rate:,
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        rate_record = @rate_repository.new_rate(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate,
          source: 'manual',
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )

        expected = OperationalDate.call
        if operational_date != expected
          rate_record.errors.add(:operational_date, 'must match operational timezone date')
          raise ActiveRecord::RecordInvalid, rate_record
        end

        @rate_repository.save!(rate_record)
        Admin::Fx::GapResolver.call(rate: rate_record)
        rate_record
      end
    end
  end
end
