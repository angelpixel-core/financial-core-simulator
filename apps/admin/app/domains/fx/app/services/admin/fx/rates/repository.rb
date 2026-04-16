# frozen_string_literal: true

module Admin
  module Fx
    module Rates
      class Repository
        def new_rate(attributes = {})
          FxDailyRate.new(attributes)
        end

        def find(rate_id)
          FxDailyRate.find(rate_id)
        end

        def find_by(operational_date:, base_currency:, quote_currency:)
          FxDailyRate.find_by(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency
          )
        end

        def find_or_initialize(operational_date:, base_currency:, quote_currency:)
          FxDailyRate.find_or_initialize_by(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency
          )
        end

        def find_latest_before(operational_date:, base_currency:, quote_currency:)
          FxDailyRate
            .where(base_currency: base_currency, quote_currency: quote_currency)
            .where("operational_date < ?", operational_date)
            .order(operational_date: :desc)
            .first
        end

        def create_placeholder!(operational_date:, base_currency:, quote_currency:, source_run_id:, source_upload_id:,
          created_context:)
          FxDailyRate.create!(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency,
            rate: nil,
            source: "placeholder",
            source_run_id: source_run_id,
            source_upload_id: source_upload_id,
            created_context: created_context
          )
        end

        def save!(rate)
          rate.save!
          rate
        end

        def destroy!(rate)
          rate.destroy!
          rate
        end

        def uncached_history_snapshot(sort_order: "desc")
          FxDailyRate.uncached { Admin::Fx::HistorySnapshot.call(sort_order: sort_order) }
        end
      end
    end
  end
end
