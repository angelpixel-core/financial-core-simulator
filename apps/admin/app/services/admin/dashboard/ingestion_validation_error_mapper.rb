module Admin
  module Dashboard
    class IngestionValidationErrorMapper
      def map(run:)
        input_json = run.input_json.is_a?(Hash) ? run.input_json : {}

        {
          source: source_for(run: run, input_json: input_json),
          field: field_for(run.error_code),
          message: run.error_message.to_s,
          occurred_at: run.updated_at&.utc&.iso8601,
          correlation_id: input_json["correlationId"] || run.run_uuid
        }
      end

      private

      def source_for(run:, input_json:)
        input_json["source"] ||
          input_json.dig("timeline", "events", 0, "source") ||
          run.error_code
      end

      def field_for(error_code)
        case error_code
        when ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING
          "accountingModel.method"
        when ::Runs::ErrorCodeMapper::VALIDATION_RISK
          "riskModel"
        when ::Runs::ErrorCodeMapper::VALIDATION_COLLATERAL
          "accounts.collateralQuote"
        when ::Runs::ErrorCodeMapper::VALIDATION_TRADE_DECIMAL
          "trade.decimal"
        when ::Runs::ErrorCodeMapper::VALIDATION_UNKNOWN_REFERENCE
          "reference"
        when ::Runs::ErrorCodeMapper::VALIDATION_DUPLICATE_SEQ
          "trades.seq"
        when ::Runs::ErrorCodeMapper::VALIDATION_INVALID_NUMBER
          "number"
        else
          "sourceEvent"
        end
      end
    end
  end
end
