# frozen_string_literal: true

module Admin
  module Dashboard
    module Repositories
      module ActiveRecord
        class FxDailyRateRepository
          def exists_for_date?(operational_date:, base_currency:, quote_currency:)
            FxDailyRate.exists?(
              operational_date: operational_date,
              base_currency: base_currency.to_s.upcase,
              quote_currency: quote_currency.to_s.upcase
            )
          end
        end
      end
    end
  end
end
