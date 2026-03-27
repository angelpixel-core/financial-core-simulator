# frozen_string_literal: true

require_relative "fcs/version"
require_relative "fcs/i18n"

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "fcs" => "FCS",
  "canonical_json" => "CanonicalJSON",
  "sha256" => "SHA256",
  "fx_converter" => "FXConverter",
  "csv_pnl" => "CsvPnL"
)
loader.ignore("#{__dir__}/financial")
loader.ignore("#{__dir__}/config")
loader.setup

# Core namespace and entrypoint for the simulator.
#
# @example Configure a custom logger
#   FCS.logger = Logger.new($stdout)
module FCS
  class << self
    attr_writer :logger
    attr_accessor :logger_class

    # Returns the logger used across the engine.
    #
    # @return [Logger, FCS::Logging::SimpleLogger]
    # @example Use the default logger
    #   FCS.logger.info("ready")
    def logger
      @logger ||= begin
        klass = logger_class || FCS::Logging::SimpleLogger
        logger = klass.new(io: $stderr)
        logger.level = FCS::Logging::SimpleLogger::WARN
        logger
      end
    end
  end
end

FCS::I18n.load_translations!
FCS::I18n.configure_locale

loader.eager_load
