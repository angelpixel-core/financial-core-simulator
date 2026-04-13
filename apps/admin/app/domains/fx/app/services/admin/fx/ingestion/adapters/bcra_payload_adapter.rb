# frozen_string_literal: true

require "bigdecimal"

module Admin
  module Fx
    module Ingestion
      module Adapters
        class BcraPayloadAdapter
          class Error < StandardError
            attr_reader :field, :entry_index, :detail_index, :raw_entry, :raw_detail

            def initialize(message:, field:, entry_index:, detail_index: nil, raw_entry: nil, raw_detail: nil)
              super(message)
              @field = field
              @entry_index = entry_index
              @detail_index = detail_index
              @raw_entry = raw_entry
              @raw_detail = raw_detail
            end
          end

          def initialize(payload)
            @payload = payload
          end

          def entries
            results = Array(payload.fetch("results"))
            results.each_with_index.map { |entry, index| Entry.new(entry, index) }
          end

          private

          attr_reader :payload

          class Entry
            def initialize(raw_entry, entry_index)
              @raw_entry = raw_entry
              @entry_index = entry_index
            end

            def date
              value = raw_entry["fecha"]
              return Date.iso8601(value.to_s) if value.present?

              raise error("Invalid date", field: "fecha")
            rescue ArgumentError
              raise error("Invalid date", field: "fecha")
            end

            def details
              raw_details = Array(raw_entry["detalle"])
              raise error("Missing detail entries", field: "detalle") if raw_details.empty?

              raw_details.each_with_index.map { |detail, index| Detail.new(detail, entry_index, index) }
            end

            private

            attr_reader :raw_entry, :entry_index

            def error(message, field:)
              Error.new(
                message: message,
                field: field,
                entry_index: entry_index,
                raw_entry: raw_entry
              )
            end
          end

          class Detail
            def initialize(raw_detail, entry_index, detail_index)
              @raw_detail = raw_detail
              @entry_index = entry_index
              @detail_index = detail_index
            end

            def currency_code
              value = raw_detail["codigoMoneda"]
              return value.to_s if value.present?

              raise error("Missing currency code", field: "codigoMoneda")
            end

            def rate
              value = raw_detail["tipoCotizacion"]
              raise error("Invalid rate", field: "tipoCotizacion") if value.blank?

              decimal = BigDecimal(value.to_s)
              raise error("Invalid rate", field: "tipoCotizacion") unless decimal.positive?

              decimal
            rescue ArgumentError
              raise error("Invalid rate", field: "tipoCotizacion")
            end

            private

            attr_reader :raw_detail, :entry_index, :detail_index

            def error(message, field:)
              Error.new(
                message: message,
                field: field,
                entry_index: entry_index,
                detail_index: detail_index,
                raw_detail: raw_detail
              )
            end
          end
        end
      end
    end
  end
end
