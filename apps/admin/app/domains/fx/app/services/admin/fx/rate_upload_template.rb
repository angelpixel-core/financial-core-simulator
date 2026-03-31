# frozen_string_literal: true

require 'caxlsx'

module Admin
  module Fx
    class RateUploadTemplate
      HEADERS = %w[operational_date rate].freeze
      SEED_RATES = {
        %w[USD ARS] => [
          [Date.new(2026, 3, 30), '100.25'],
          [Date.new(2026, 3, 31), '101.10']
        ],
        %w[BTC USD] => [
          [Date.new(2026, 3, 30), '25000']
        ],
        %w[BTC ARS] => [
          [Date.new(2026, 3, 30), '2500000']
        ],
        %w[ETH USD] => [
          [Date.new(2026, 3, 30), '1800']
        ],
        %w[ETH ARS] => [
          [Date.new(2026, 3, 30), '180000']
        ]
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

        supported_pairs.each do |base_currency, quote_currency|
          workbook.add_worksheet(name: sheet_name_for(base_currency, quote_currency)) do |sheet|
            sheet.add_row(HEADERS, style: header_style)
            seed_rows_for(base_currency, quote_currency).each do |row|
              sheet.add_row(row)
            end
          end
        end

        Template.new(
          data: package.to_stream.read,
          filename: 'fx_rates_template.xlsx',
          content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
      end

      private

      def supported_pairs
        Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS
      end

      def seed_rows_for(base_currency, quote_currency)
        SEED_RATES.fetch([base_currency, quote_currency], [])
      end

      def sheet_name_for(base_currency, quote_currency)
        "#{base_currency}-#{quote_currency}"
      end
    end
  end
end
