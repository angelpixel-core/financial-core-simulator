module Runs
  class ErrorCodeMapper
    FALLBACK_ERROR = "ERR_EXECUTION_FAILURE"
    VALIDATION_GENERAL = "ERR_VALIDATION_GENERAL"
    VALIDATION_ACCOUNTING = "ERR_VALIDATION_ACCOUNTING_MODEL"
    VALIDATION_RISK = "ERR_VALIDATION_RISK_MODEL"
    VALIDATION_COLLATERAL = "ERR_VALIDATION_COLLATERAL"
    VALIDATION_TRADE_DECIMAL = "ERR_VALIDATION_TRADE_DECIMAL"
    VALIDATION_UNKNOWN_REFERENCE = "ERR_VALIDATION_UNKNOWN_REFERENCE"
    VALIDATION_DUPLICATE_SEQ = "ERR_VALIDATION_DUPLICATE_SEQ"
    VALIDATION_INVALID_NUMBER = "ERR_VALIDATION_INVALID_NUMBER"

    def self.call(error)
      return map_domain_error(error) if error.respond_to?(:code) && error.code.present?

      case error
      when JSON::ParserError, ArgumentError
        FCS::Errors::ERR_INVALID_INPUT
      else
        FALLBACK_ERROR
      end
    end

    def self.map_domain_error(error)
      case error.code
      when FCS::Errors::ERR_VALIDATION
        map_validation_field(error)
      when FCS::Errors::ERR_UNKNOWN_REFERENCE
        VALIDATION_UNKNOWN_REFERENCE
      when FCS::Errors::ERR_DUPLICATE_SEQ
        VALIDATION_DUPLICATE_SEQ
      when FCS::Errors::ERR_INVALID_NUMBER
        VALIDATION_INVALID_NUMBER
      else
        error.code
      end
    end

    def self.map_validation_field(error)
      details = error.respond_to?(:details) ? error.details : {}
      field = details["field"] || details[:field]

      return VALIDATION_GENERAL if field.blank?
      return VALIDATION_ACCOUNTING if field.start_with?("accountingModel")
      return VALIDATION_RISK if field.start_with?("riskModel")
      return VALIDATION_COLLATERAL if field.start_with?("accounts.collateralQuote")
      return VALIDATION_TRADE_DECIMAL if %w[quantityBase priceQuotePerBase fee.amountQuote].include?(field)

      VALIDATION_GENERAL
    end
  end
end
