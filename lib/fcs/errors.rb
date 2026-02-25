# frozen_string_literal: true

module FCS
  class Error < StandardError
    attr_reader :code, :details

    def initialize(code, message = nil, details: {})
      @code = code
      @details = details
      super(message || code)
    end
  end

  module Errors
    ERR_POSITION_NEGATIVE  = "ERR_POSITION_NEGATIVE"
    ERR_MISSING_SNAPSHOT   = "ERR_MISSING_SNAPSHOT"
    ERR_INVALID_INPUT      = "ERR_INVALID_INPUT"
    ERR_UNSUPPORTED_SCHEMA = "ERR_UNSUPPORTED_SCHEMA"
  end
end
