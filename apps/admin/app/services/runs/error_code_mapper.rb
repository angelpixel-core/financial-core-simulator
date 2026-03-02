module Runs
  class ErrorCodeMapper
    FALLBACK_ERROR = "ERR_EXECUTION_FAILURE"

    def self.call(error)
      return error.code if error.respond_to?(:code) && error.code.present?

      case error
      when JSON::ParserError, ArgumentError
        FCS::Errors::ERR_INVALID_INPUT
      else
        FALLBACK_ERROR
      end
    end
  end
end
