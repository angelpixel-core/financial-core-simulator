# frozen_string_literal: true

module Admin
  module Fx
    module Gaps
      class Repository
        def open_for(operational_date:, base_currency:, quote_currency:)
          FxRateGap.open_for(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency
          )
        end

        def create_open!(operational_date:, base_currency:, quote_currency:, placeholder_rate_id:, source_run_id:,
          source_upload_id:, created_context:)
          FxRateGap.create!(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency,
            status: "open",
            placeholder_rate_id: placeholder_rate_id,
            source_run_id: source_run_id,
            source_upload_id: source_upload_id,
            created_context: created_context
          )
        end
      end
    end
  end
end
