# frozen_string_literal: true

module FCS
  # Error type with structured code and details.
  class Error < StandardError
    attr_reader :code, :details

    def initialize(code, message = nil, details: {})
      @code = code
      @details = details
      super(message || code)
    end
  end

  module Errors
    ERR_POSITION_NEGATIVE = "ERR_POSITION_NEGATIVE"
    ERR_MISSING_SNAPSHOT = "ERR_MISSING_SNAPSHOT"
    ERR_INVALID_INPUT = "ERR_INVALID_INPUT"
    ERR_UNSUPPORTED_SCHEMA = "ERR_UNSUPPORTED_SCHEMA"
    ERR_RISK_REJECTION = "ERR_RISK_REJECTION"
    ERR_RISK_MAINTENANCE_MARGIN = "ERR_RISK_MAINTENANCE_MARGIN"
    ERR_RISK_LIQUIDATABLE = "ERR_RISK_LIQUIDATABLE"
    ERR_RISK_CONFIG_INVALID = "ERR_RISK_CONFIG_INVALID"

    # Validator / ingestion
    ERR_VALIDATION = "ERR_VALIDATION"
    ERR_DUPLICATE_ID = "ERR_DUPLICATE_ID"
    ERR_INVALID_NUMBER = "ERR_INVALID_NUMBER"
    ERR_UNKNOWN_REFERENCE = "ERR_UNKNOWN_REFERENCE"
    ERR_DUPLICATE_SEQ = "ERR_DUPLICATE_SEQ"
  end
end
