module Admin
  module Validation
    class IngestionValidationErrorMapper
      def map(run: nil, validation_error: nil)
        return map_validation_error(validation_error) if validation_error
        return map_failed_run(run) if run

        {}
      end

      private

      def map_failed_run(run)
        input_json = run.input_json.is_a?(Hash) ? run.input_json : {}

        {
          source: source_for(run: run, input_json: input_json),
          field: field_for(run.error_code),
          message: run.error_message.to_s,
          occurred_at: run.updated_at&.utc&.iso8601,
          correlation_id: input_json["correlationId"] || run.run_uuid
        }
      end

      def map_validation_error(validation_error)
        run = validation_error.run
        input_json = run&.input_json.is_a?(Hash) ? run.input_json : {}
        occurred_at = validation_error.occurred_at || validation_error.created_at

        {
          source: validation_error.source.presence || source_for(run: run, input_json: input_json),
          field: validation_error.field.presence,
          message: validation_error.message.to_s,
          occurred_at: occurred_at&.utc&.iso8601,
          correlation_id: validation_error.correlation_id.presence || input_json["correlationId"] || run&.run_uuid
        }
      end

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
