module FCS
  module Logging
    class SimpleLogger
      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3
      FATAL = 4

      attr_accessor :level

      def initialize(io:, level: WARN)
        @io = io
        @level = level
      end

      def debug(message)
        log("DEBUG", DEBUG, message)
      end

      def info(message)
        log("INFO", INFO, message)
      end

      def warn(message)
        log("WARN", WARN, message)
      end

      def error(message)
        log("ERROR", ERROR, message)
      end

      def fatal(message)
        log("FATAL", FATAL, message)
      end

      private

      def log(label, severity, message)
        return if severity < @level

        @io.puts("[#{label}] #{message}")
      end
    end
  end
end
