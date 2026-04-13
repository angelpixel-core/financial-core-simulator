# frozen_string_literal: true

module Admin
  module Fx
    class RateUpserter
      def self.call(
        operational_date:,
        base_currency:,
        quote_currency:,
        rate:,
        source: "manual",
        source_id: nil,
        source_run_id: nil,
        source_upload_id: nil,
        enforce_operational_date: true,
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        new.call(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency,
          rate: rate,
          source: source,
          source_id: source_id,
          source_run_id: source_run_id,
          source_upload_id: source_upload_id,
          enforce_operational_date: enforce_operational_date,
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
        source: "manual",
        source_id: nil,
        source_run_id: nil,
        source_upload_id: nil,
        enforce_operational_date: true,
        created_by_id: nil,
        created_by_role: nil,
        created_context: {}
      )
        expected = OperationalDate.call
        rate_record = FxDailyRate.find_or_initialize_by(
          operational_date: operational_date,
          base_currency: base_currency,
          quote_currency: quote_currency
        )

        if enforce_operational_date && operational_date != expected
          rate_record.errors.add(:operational_date, "must match operational timezone date")
          raise ActiveRecord::RecordInvalid, rate_record
        end

        if source.to_s == "placeholder"
          return rate_record if rate_record.persisted? && rate_record.rate.present?
          return rate_record if rate_record.persisted? && rate_record.placeholder?
        end

        context = rate_record.created_context || {}
        rate_record.assign_attributes(
          rate: rate,
          source: source,
          source_id: source_id,
          source_rate_id: nil,
          source_run_id: source_run_id,
          source_upload_id: source_upload_id,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: context.merge(created_context)
        )

        rate_record.save!
        Admin::Fx::GapResolver.call(rate: rate_record) unless rate_record.placeholder?
        rate_record
      end
    end
  end
end
