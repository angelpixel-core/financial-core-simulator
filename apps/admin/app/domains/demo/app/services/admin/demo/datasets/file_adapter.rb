# frozen_string_literal: true

module Admin
  module Demo
    module Datasets
      class FileAdapter < FCS::Ports::FileLoader
        ParseResult = Struct.new(:valid?, :input, :errors, keyword_init: true)

        def initialize(parser: Admin::DemoDataset::ExcelToInputParser)
          @parser = parser
        end

        def parse(file_path:, timeline_enabled: false)
          result = @parser.call(file_path: file_path, timeline_enabled: timeline_enabled)

          ParseResult.new(
            valid?: result.valid?,
            input: result.input,
            errors: normalize_errors(result.errors)
          )
        end

        def load(file_path:, timeline_enabled: false, **_options)
          parse(file_path: file_path, timeline_enabled: timeline_enabled)
        end

        private

        def normalize_errors(errors)
          Array(errors).map do |entry|
            {
              line: entry[:line] || entry['line'],
              code: (entry[:code] || entry['code']).to_s,
              message: entry[:message] || entry['message']
            }.compact
          end
        end
      end
    end
  end
end
