# frozen_string_literal: true

require "csv"
require "json"

module FCS
  module Reporting
    # Validates CSV artifacts against the canonical JSON payload.
    #
    # @example
    #   reconciler = FCS::Reporting::CsvArtifactReconciler.new
    #   reconciler.validate!(json_path: json_path, positions_path: positions_path, pnl_path: pnl_path)
    class CsvArtifactReconciler
      POSITION_NUMERIC_FIELDS = %w[quantity avg_cost].freeze
      PNL_NUMERIC_FIELDS = %w[
        realized_pnl_quote
        fees_quote
        realized_net_pnl_quote
        unrealized_pnl_quote
        total_pnl_quote
        total_pnl_usd
      ].freeze

      # @param json_path [String]
      # @param positions_path [String]
      # @param pnl_path [String]
      # @return [void]
      # @raise [FCS::Error]
      def validate!(json_path:, positions_path:, pnl_path:)
        payload = JSON.parse(File.read(json_path))
        accounts = payload.fetch("accounts")
        global = payload.fetch("global")

        positions_rows = CSV.read(positions_path, headers: true)
        pnl_rows = CSV.read(pnl_path, headers: true)

        validate_headers!(positions_rows.headers, CsvPositions::HEADER, "positions.csv")
        validate_headers!(pnl_rows.headers, CsvPnL::HEADER, "pnl.csv")

        expected_positions = expected_positions_rows(accounts)
        expected_pnl = expected_pnl_rows(accounts)

        compare_rows!(
          label: "positions.csv",
          expected_rows: expected_positions,
          actual_rows: index_rows(positions_rows),
          numeric_fields: POSITION_NUMERIC_FIELDS
        )
        compare_rows!(
          label: "pnl.csv",
          expected_rows: expected_pnl,
          actual_rows: index_rows(pnl_rows),
          numeric_fields: PNL_NUMERIC_FIELDS
        )

        validate_global_totals!(
          global: global,
          pnl_rows: pnl_rows
        )
      end

      private

      def validate_headers!(headers, expected_headers, label)
        return if headers == expected_headers

        raise_validation_error!(
          message: t("fcs.reporting.csv.header_mismatch", label: label),
          mismatch: "csv_header_mismatch",
          details: {
            "expected_headers" => expected_headers,
            "actual_headers" => headers
          }
        )
      end

      def expected_positions_rows(accounts)
        accounts.sort_by { |acc| acc.fetch("accountId") }.flat_map do |acc|
          acc.fetch("markets").sort_by { |m| m.fetch("marketId") }.map do |m|
            {
              "account_id" => acc.fetch("accountId"),
              "market_id" => m.fetch("marketId"),
              "quantity" => serialize_decimal(m.fetch("quantity")),
              "avg_cost" => serialize_decimal(m.fetch("avgCost"))
            }
          end
        end
      end

      def expected_pnl_rows(accounts)
        accounts.sort_by { |acc| acc.fetch("accountId") }.flat_map do |acc|
          acc.fetch("markets").sort_by { |m| m.fetch("marketId") }.map do |m|
            {
              "account_id" => acc.fetch("accountId"),
              "market_id" => m.fetch("marketId"),
              "realized_pnl_quote" => serialize_decimal(m.fetch("realizedPnLQuote")),
              "fees_quote" => serialize_decimal(m.fetch("feesQuote")),
              "realized_net_pnl_quote" => serialize_decimal(m.fetch("realizedNetPnLQuote")),
              "unrealized_pnl_quote" => serialize_decimal(m.fetch("unrealizedPnLQuote")),
              "total_pnl_quote" => serialize_decimal(m.fetch("totalPnLQuote")),
              "total_pnl_usd" => serialize_decimal(m["totalPnLUsd"])
            }
          end
        end
      end

      def index_rows(rows)
        rows.each_with_object({}) do |row, acc|
          key = [row["account_id"], row["market_id"]]
          if acc.key?(key)
            raise_validation_error!(
              message: t("fcs.reporting.csv.duplicate_rows"),
              mismatch: "csv_row_duplicate",
              details: {
                "account_id" => key[0],
                "market_id" => key[1]
              }
            )
          end

          acc[key] = row.to_h
        end
      end

      def compare_rows!(label:, expected_rows:, actual_rows:, numeric_fields:)
        expected_rows.each do |expected|
          validate_expected_row!(
            expected: expected,
            actual_rows: actual_rows,
            numeric_fields: numeric_fields,
            label: label
          )
        end

        extra = actual_rows.keys - expected_rows.map { |row| [row["account_id"], row["market_id"]] }
        return if extra.empty?

        raise_validation_error!(
          message: t("fcs.reporting.csv.unexpected_rows", label: label),
          mismatch: "csv_row_unexpected",
          details: {
            "unexpected_rows" => extra.map { |row| {"account_id" => row[0], "market_id" => row[1]} }
          }
        )
      end

      def validate_expected_row!(expected:, actual_rows:, numeric_fields:, label:)
        key = [expected.fetch("account_id"), expected.fetch("market_id")]
        actual = actual_rows[key]

        if actual.nil?
          raise_validation_error!(
            message: t("fcs.reporting.csv.row_missing", label: label),
            mismatch: "csv_row_missing",
            details: {
              "account_id" => key[0],
              "market_id" => key[1]
            }
          )
        end

        numeric_fields.each do |field|
          expected_value = expected[field]
          actual_value = normalize_blank(actual[field])
          next if decimals_equal?(expected_value, actual_value)

          raise_validation_error!(
            message: t("fcs.reporting.csv.row_mismatch", label: label),
            mismatch: "csv_row_mismatch",
            details: {
              "account_id" => key[0],
              "market_id" => key[1],
              "field" => field,
              "expected" => expected_value,
              "actual" => actual_value
            }
          )
        end
      end

      def validate_global_totals!(global:, pnl_rows:)
        totals = {
          "realized_pnl_quote" => FCS::Types::Decimal18.new(0),
          "fees_quote" => FCS::Types::Decimal18.new(0),
          "realized_net_pnl_quote" => FCS::Types::Decimal18.new(0),
          "unrealized_pnl_quote" => FCS::Types::Decimal18.new(0),
          "total_pnl_quote" => FCS::Types::Decimal18.new(0)
        }

        total_usd_values = []

        pnl_rows.each do |row|
          totals.each_key do |field|
            value = normalize_blank(row[field])
            if value.nil?
              raise_validation_error!(
                message: t("fcs.reporting.csv.totals_missing_value"),
                mismatch: "csv_global_total_missing",
                details: {
                  "field" => field
                }
              )
            end

            totals[field] += FCS::Types::Decimal18.from_string(value.to_s)
          end
          total_usd_values << normalize_blank(row["total_pnl_usd"])
        end

        totals.each do |field, value|
          expected = serialize_decimal(global.fetch(camelize_field(field)))
          actual = value.to_s
          next if decimals_equal?(expected, actual)

          raise_validation_error!(
            message: t("fcs.reporting.csv.totals_mismatch"),
            mismatch: "csv_global_total_mismatch",
            details: {
              "field" => field,
              "expected" => expected,
              "actual" => actual
            }
          )
        end

        expected_total_usd = global["totalPnLUsd"]
        nil_count = total_usd_values.count(&:nil?)
        if nil_count.positive?
          if nil_count == total_usd_values.size
            return if expected_total_usd.nil?

            raise_validation_error!(
              message: t("fcs.reporting.csv.usd_totals_missing"),
              mismatch: "csv_global_total_usd_missing",
              details: {
                "expected" => serialize_decimal(expected_total_usd)
              }
            )
          end

          raise_validation_error!(
            message: t("fcs.reporting.csv.usd_totals_partial"),
            mismatch: "csv_global_total_usd_partial",
            details: {
              "expected" => serialize_decimal(expected_total_usd)
            }
          )
        end

        if expected_total_usd.nil?
          raise_validation_error!(
            message: t("fcs.reporting.csv.usd_totals_unexpected"),
            mismatch: "csv_global_total_usd_unexpected",
            details: {
              "actual" => total_usd_values.map { |value| serialize_decimal(value) }
            }
          )
        end

        actual_total_usd = total_usd_values.reduce(FCS::Types::Decimal18.new(0)) do |sum, value|
          sum + FCS::Types::Decimal18.from_string(value.to_s)
        end

        expected_usd = serialize_decimal(expected_total_usd)
        actual_usd = actual_total_usd.to_s
        return if decimals_equal?(expected_usd, actual_usd)

        raise_validation_error!(
          message: t("fcs.reporting.csv.usd_totals_mismatch"),
          mismatch: "csv_global_total_usd_mismatch",
          details: {
            "expected" => expected_usd,
            "actual" => actual_usd
          }
        )
      end

      def camelize_field(field)
        case field
        when "realized_pnl_quote" then "realizedPnLQuote"
        when "fees_quote" then "feesQuote"
        when "realized_net_pnl_quote" then "realizedNetPnLQuote"
        when "unrealized_pnl_quote" then "unrealizedPnLQuote"
        when "total_pnl_quote" then "totalPnLQuote"
        else
          field
        end
      end

      def serialize_decimal(value)
        return nil if value.nil?

        FCS::Types::Decimal18.from_string(value.to_s).to_s
      end

      def decimals_equal?(left, right)
        left = normalize_blank(left)
        right = normalize_blank(right)
        return left.nil? && right.nil? if left.nil? || right.nil?

        FCS::Types::Decimal18.from_string(left.to_s).atoms == FCS::Types::Decimal18.from_string(right.to_s).atoms
      end

      def normalize_blank(value)
        return nil if value.nil?
        return nil if value.is_a?(String) && value.strip.empty?

        value
      end

      def raise_validation_error!(message:, mismatch:, details: {})
        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          message,
          details: {
            "mismatch" => mismatch,
            "impact" => t("fcs.reporting.csv.impact"),
            "next_action" => t("fcs.reporting.csv.next_action")
          }.merge(details)
        )
      end

      def t(key, **opts)
        ::I18n.t(key, **opts)
      end
    end
  end
end
