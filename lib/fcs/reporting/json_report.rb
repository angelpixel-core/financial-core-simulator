# frozen_string_literal: true

require 'json'
require 'time'
require 'fileutils'

module FCS
  module Reporting
    class JsonReport
      def write!(output_dir:, payload:)
        FileUtils.mkdir_p(output_dir)

        path = File.join(output_dir, 'result.json')
        File.write(path, JSON.pretty_generate(canonicalize(payload)) + "\n")
        path
      end

      private

      def canonicalize(value)
        case value
        when Hash
          value.keys.sort.each_with_object({}) do |key, normalized|
            normalized[key] = canonicalize(value[key])
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
