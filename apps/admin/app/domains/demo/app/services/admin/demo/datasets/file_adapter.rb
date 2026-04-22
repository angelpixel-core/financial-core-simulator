# frozen_string_literal: true

module Admin
  module Demo
    module Datasets
      class FileAdapter < FCS::Ports::FileLoader
        ParseResult = Struct.new(:valid?, :input, :errors, keyword_init: true)

        def initialize(parser: Admin::DemoDataset::ExcelToInputParser)
          @parser = parser
        end

        def parse(file_path:, timeline_enabled: false, stage: :process)
          result = parse_with_optional_stage(file_path: file_path, timeline_enabled: timeline_enabled, stage: stage)

          ParseResult.new(
            valid?: result.valid?,
            input: result.input,
            errors: normalize_errors(result.errors)
          )
        end

        def load(file_path:, timeline_enabled: false, stage: :process, **_options)
          parse(file_path: file_path, timeline_enabled: timeline_enabled, stage: stage)
        end

        private

        def parse_with_optional_stage(file_path:, timeline_enabled:, stage:)
          @parser.call(file_path: file_path, timeline_enabled: timeline_enabled, stage: stage)
        rescue ArgumentError => e
          raise unless e.message.include?("stage")

          @parser.call(file_path: file_path, timeline_enabled: timeline_enabled)
        end

        def normalize_errors(errors)
          Array(errors).map do |entry|
            {
              line: entry[:line] || entry["line"],
              code: (entry[:code] || entry["code"]).to_s,
              message: entry[:message] || entry["message"]
            }.compact
          end
        end
      end
    end
  end
end
