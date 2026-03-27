# frozen_string_literal: true

require "json"

module FCS
  module Ingestion
    # Parses input JSON from disk.
    #
    # @example
    #   input = FCS::Ingestion::Parser.new.parse_file("data/input.json")
    class Parser
      # @param path [String]
      # @return [Hash]
      # @raise [FCS::Error]
      def parse_file(path)
        raw = File.read(path)
        JSON.parse(raw)
      rescue Errno::ENOENT
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, t("fcs.ingestion.parser.input_file_not_found"),
          details: {path: path})
      rescue Errno::EACCES
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, t("fcs.ingestion.parser.input_file_not_readable"),
          details: {path: path})
      rescue JSON::ParserError
        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          t("fcs.ingestion.parser.invalid_json"),
          details: {errorClass: "JSON::ParserError", errorCode: "INVALID_JSON_SYNTAX"}
        )
      end

      def t(key, **opts)
        ::I18n.t(key, **opts)
      end
    end
  end
end
