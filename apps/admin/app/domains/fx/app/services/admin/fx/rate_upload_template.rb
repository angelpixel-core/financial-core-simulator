# frozen_string_literal: true

require "caxlsx"

module Admin
  module Fx
    class RateUploadTemplate
      HEADERS = %w[id operational_date base_currency quote_currency rate].freeze
      TEMPLATE_START_DATE = Date.new(2026, 3, 1)
      TEMPLATE_END_DATE = Date.new(2026, 3, 30)
      TEMPLATE_SHEET_NAME = "FX Rates"
      TEMPLATE_PAIRS = [
        %w[USD ARS],
        %w[BTC USD],
        %w[ETH USD],
        %w[BTC ARS],
        %w[ETH ARS]
      ].freeze
      RATE_BASES = {
        %w[USD ARS] => 900.0,
        %w[BTC USD] => 65_000.0,
        %w[ETH USD] => 3_500.0,
        %w[BTC ARS] => 58_500_000.0,
        %w[ETH ARS] => 3_150_000.0
      }.freeze

      Template = Struct.new(:data, :filename, :content_type, keyword_init: true)

      def self.generate
        new.generate
      end

      def generate
        package = Axlsx::Package.new
        workbook = package.workbook
        styles = workbook.styles
        header_style = styles.add_style(b: true)

        workbook.add_worksheet(name: TEMPLATE_SHEET_NAME) do |sheet|
          sheet.add_row(HEADERS, style: header_style)
          build_rows.each { |row| sheet.add_row(row) }
        end

        Template.new(
          data: package.to_stream.read,
          filename: "fx_rates_template.xlsx",
          content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
      end

      private

      def build_rows
        rows = []
        template_dates.each do |date|
          TEMPLATE_PAIRS.each do |base_currency, quote_currency|
            rows << [
              row_id_for(date, base_currency, quote_currency),
              date,
              base_currency,
              quote_currency,
              rate_for(date, base_currency, quote_currency)
            ]
          end
        end
        rows
      end

      def template_dates
        (TEMPLATE_START_DATE..TEMPLATE_END_DATE).to_a.reverse
      end

      def row_id_for(date, base_currency, quote_currency)
        "#{date}-#{base_currency}-#{quote_currency}"
      end

      def rate_for(date, base_currency, quote_currency)
        RATE_BASES.fetch([base_currency, quote_currency]) + date.day
      end
    end
  end
end
