# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module FCS
  module Reporting
    # Writes canonical JSON report output.
    #
    # @example
    #   FCS::Reporting::JsonReport.new.write!(output_dir: "tmp/fcs", payload: payload)
    class JsonReport
      # @param output_dir [String]
      # @param payload [Hash]
      # @return [String] path to result.json
      def write!(output_dir:, payload:)
        FileUtils.mkdir_p(output_dir)

        path = File.join(output_dir, "result.json")
        File.write(path, "#{JSON.pretty_generate(canonicalize(payload))}\n")
        path
      end

      private

      def canonicalize(value)
        case value
        when Hash
          value.keys.sort.to_h do |key|
            [key, canonicalize(value[key])]
          end
        when Array
          value.map { |item| canonicalize(item) }
        else
          value
        end
      end
    end
  end
end
