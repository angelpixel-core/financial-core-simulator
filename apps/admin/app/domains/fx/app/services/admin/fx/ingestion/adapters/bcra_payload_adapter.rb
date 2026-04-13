# typed: true
# frozen_string_literal: true

require "bigdecimal"
require "sorbet-runtime"

module Admin
  module Fx
    module Ingestion
      module Adapters
        class BcraPayloadAdapter
          extend T::Sig

          class Error < StandardError
            extend T::Sig

            sig { returns(String) }
            attr_reader :field

            sig { returns(Integer) }
            attr_reader :entry_index

            sig { returns(T.nilable(Integer)) }
            attr_reader :detail_index

            sig { returns(T.nilable(T::Hash[T.untyped, T.untyped])) }
            attr_reader :raw_entry

            sig { returns(T.nilable(T::Hash[T.untyped, T.untyped])) }
            attr_reader :raw_detail

            sig do
              params(
                message: String,
                field: String,
                entry_index: Integer,
                detail_index: T.nilable(Integer),
                raw_entry: T.nilable(T::Hash[T.untyped, T.untyped]),
                raw_detail: T.nilable(T::Hash[T.untyped, T.untyped])
              ).void
            end
            def initialize(message:, field:, entry_index:, detail_index: nil, raw_entry: nil, raw_detail: nil)
              super(message)
              @field = field
              @entry_index = entry_index
              @detail_index = detail_index
              @raw_entry = raw_entry
              @raw_detail = raw_detail
            end
          end

          sig { params(payload: T::Hash[T.untyped, T.untyped]).void }
          def initialize(payload)
            @payload = payload
          end

          # @return [Array<Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter::Entry>]
          sig { returns(T::Array[Entry]) }
          def entries
            results = Array(payload.fetch("results"))
            results.each_with_index.map { |entry, index| Entry.new(entry, index) }
          end

          private

          sig { returns(T::Hash[T.untyped, T.untyped]) }
          attr_reader :payload

          class Entry
            extend T::Sig

            sig do
              params(
                raw_entry: T::Hash[T.untyped, T.untyped],
                entry_index: Integer
              ).void
            end
            def initialize(raw_entry, entry_index)
              @raw_entry = raw_entry
              @entry_index = entry_index
            end

            # @return [Date]
            sig { returns(Date) }
            def date
              value = raw_entry["fecha"]
              return Date.iso8601(value.to_s) if value.present?

              raise error("Invalid date", field: "fecha")
            rescue ArgumentError
              raise error("Invalid date", field: "fecha")
            end

            # @return [Array<Admin::Fx::Ingestion::Adapters::BcraPayloadAdapter::Detail>]
            sig { returns(T::Array[Detail]) }
            def details
              raw_details = Array(raw_entry["detalle"])
              raise error("Missing detail entries", field: "detalle") if raw_details.empty?

              raw_details.each_with_index.map { |detail, index| Detail.new(detail, entry_index, index) }
            end

            private

            sig { returns(T::Hash[T.untyped, T.untyped]) }
            attr_reader :raw_entry

            sig { returns(Integer) }
            attr_reader :entry_index

            sig { params(message: String, field: String).returns(Error) }
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
            extend T::Sig

            sig do
              params(
                raw_detail: T::Hash[T.untyped, T.untyped],
                entry_index: Integer,
                detail_index: Integer
              ).void
            end
            def initialize(raw_detail, entry_index, detail_index)
              @raw_detail = raw_detail
              @entry_index = entry_index
              @detail_index = detail_index
            end

            # @return [String]
            sig { returns(String) }
            def currency_code
              value = raw_detail["codigoMoneda"]
              return value.to_s if value.present?

              raise error("Missing currency code", field: "codigoMoneda")
            end

            # @return [BigDecimal]
            sig { returns(BigDecimal) }
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

            sig { returns(T::Hash[T.untyped, T.untyped]) }
            attr_reader :raw_detail

            sig { returns(Integer) }
            attr_reader :entry_index

            sig { returns(Integer) }
            attr_reader :detail_index

            sig { params(message: String, field: String).returns(Error) }
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
