# frozen_string_literal: true

module Admin
  module Fx
    class CarryForwardRate
      def self.call(
        operational_date:,
        base_currency:,
        quote_currency:,
        source: 'carry_forward',
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        new.call(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          source: source,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: created_context
        )
      end

      def call(
        operational_date:,
        base_currency:,
        quote_currency:,
        source: 'carry_forward',
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        source_value = source.to_s
        source_value = 'carry_forward' unless source_value == 'carry_forward'
        expected = OperationalDate.call
        if operational_date != expected
          rate_record = FxDailyRate.new(operational_date: operational_date)
          rate_record.errors.add(:operational_date, 'must match operational timezone date')
          raise ActiveRecord::RecordInvalid, rate_record
        end

        prior_date = operational_date - 1.day
        prior_rate = FxDailyRate.find_by(
          operational_date: prior_date,
          base_currency: base_currency,
          quote_currency: quote_currency
        )

        unless prior_rate
          rate_record = FxDailyRate.new(operational_date: operational_date)
          rate_record.errors.add(:base, 'no prior rate available to carry forward')
          raise ActiveRecord::RecordInvalid, rate_record
        end

        rate_record = FxDailyRate.find_or_initialize_by(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency
        )

        return rate_record if rate_record.persisted? && !rate_record.placeholder? && rate_record.rate.present?

        context = rate_record.created_context || {}
        rate_record.assign_attributes(
          rate: prior_rate.rate,
          source: source_value,
          source_rate_id: prior_rate.id,
          source_run_id: nil,
          source_upload_id: nil,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: context.merge(created_context)
        )

        rate_record.save!

        Admin::Fx::GapResolver.call(rate: rate_record)
        rate_record
      end
    end
  end
end
