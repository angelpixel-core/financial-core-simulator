# frozen_string_literal: true

require "json"

module FCS
  module Ingestion
    class Parser
      def parse_file(path)
        raw = File.read(path)
        JSON.parse(raw)
      rescue Errno::ENOENT
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "Input file not found", details: { path: path })
      rescue Errno::EACCES
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "Input file is not readable", details: { path: path })
      rescue JSON::ParserError
        raise FCS::Error.new(
          FCS::Errors::ERR_INVALID_INPUT,
          "Invalid JSON",
          details: { errorClass: "JSON::ParserError", errorCode: "INVALID_JSON_SYNTAX" }
        )
      end
    end
  end
end
