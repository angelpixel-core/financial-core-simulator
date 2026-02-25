# frozen_string_literal: true

require "json"

module FCS
  module Ingestion
    class Parser
      def parse_file(path)
        raw = File.read(path)
        JSON.parse(raw)
      rescue JSON::ParserError => e
        raise FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT, "Invalid JSON", details: { error: e.message })
      end
    end
  end
end
