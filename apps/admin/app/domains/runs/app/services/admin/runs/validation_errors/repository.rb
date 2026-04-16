module Admin
  module Runs
    module ValidationErrors
      class Repository
        VALIDATION_ERROR_CODES = [
          ::Runs::ErrorCodeMapper::VALIDATION_GENERAL,
          ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
          ::Runs::ErrorCodeMapper::VALIDATION_RISK,
          ::Runs::ErrorCodeMapper::VALIDATION_COLLATERAL,
          ::Runs::ErrorCodeMapper::VALIDATION_TRADE_DECIMAL,
          ::Runs::ErrorCodeMapper::VALIDATION_UNKNOWN_REFERENCE,
          ::Runs::ErrorCodeMapper::VALIDATION_DUPLICATE_SEQ,
          ::Runs::ErrorCodeMapper::VALIDATION_INVALID_NUMBER
        ].freeze

        def initialize(error_mapper: Admin::Validation::IngestionValidationErrorMapper.new)
          @error_mapper = error_mapper
        end

        def validation_error?(run:)
          return false if run.nil?

          VALIDATION_ERROR_CODES.include?(run.error_code)
        end

        def issues_for(run:)
          return [] unless validation_error?(run: run)

          [@error_mapper.map(run: run).merge(severity: 'error')]
        end
      end
    end
  end
end
