# frozen_string_literal: true

module Admin
  module Fx
    module Repositories
      module ActiveRecord
        class DailyRateRepository
          def find(rate_id)
            FxDailyRate.find(rate_id)
          end

          def find_or_initialize(operational_date:, base_currency:, quote_currency:)
            FxDailyRate.find_or_initialize_by(
              operational_date: operational_date,
              base_currency: base_currency,
              quote_currency: quote_currency
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
end
