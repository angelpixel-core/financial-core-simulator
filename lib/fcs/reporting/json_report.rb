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
        File.write(path, JSON.pretty_generate(payload) + "\n")
        path
      end
    end
  end
end
