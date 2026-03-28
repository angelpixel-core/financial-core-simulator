# frozen_string_literal: true

require "caxlsx"
require "fileutils"
require "securerandom"
require "time"

module Admin
  module DemoDataset
    class ExcelGenerator
      DAYS = 30
      TRADES_PER_DAY_RANGE = (3..8)
      ERROR_RATE = 0.08
      ACCOUNTS = ["acc-1"].freeze
      MARKETS = ["ETH-USD"].freeze

      HEADERS = %w[
        trade_id account_id market_id timestamp seq
        side quantity_base price_quote_per_base
      ].freeze

      def initialize(output_dir:)
        @output_dir = output_dir
      end

      def generate_valid
        ensure_output_dir
        trades = generate_trades
        write_excel(valid_path, trades)
        valid_path
      end

      def generate_invalid
        ensure_output_dir
        trades = generate_trades
        inject_errors!(trades)
        write_excel(invalid_path, trades)
        invalid_path
      end

      def valid_path
        File.join(@output_dir, "trades_valid.xlsx")
      end

      def invalid_path
        File.join(@output_dir, "trades_invalid.xlsx")
      end

      private

      def ensure_output_dir
        FileUtils.mkdir_p(@output_dir)
      end

      def generate_trades
        trades = []
        seq = 1
        inventories = Hash.new(0.0)
        start_date = Time.now.utc - (DAYS * 24 * 60 * 60)

        DAYS.times do |day|
          date = start_date + (day * 24 * 60 * 60)
          trades_per_day = rand(TRADES_PER_DAY_RANGE)
          timestamps = Array.new(trades_per_day) { rand(0..86_399) }.sort

          timestamps.each do |offset|
            account_id = ACCOUNTS.sample
            market_id = MARKETS.sample
            key = "#{account_id}|#{market_id}"
            side = inventories[key] <= 0 ? "BUY" : %w[BUY SELL].sample
            quantity_base = 1.0

            if side == "SELL"
              quantity_base = [quantity_base, inventories[key]].min
              inventories[key] -= quantity_base
            else
              inventories[key] += quantity_base
            end

            trades << {
              trade_id: "t-#{SecureRandom.hex(4)}",
              account_id: account_id,
              market_id: market_id,
              timestamp: (date + offset).to_i,
              seq: seq,
              side: side,
              quantity_base: quantity_base,
              price_quote_per_base: rand(80.0..140.0).round(2),
              invalid: false
            }
            seq += 1
          end
        end

        trades
      end

      def inject_errors!(trades)
        error_count = (trades.size * ERROR_RATE).to_i
        candidates = trades.drop(1)
        error_rows = candidates.sample(error_count)

        error_rows.each do |row|
          case rand(1..6)
          when 1
            row[:seq] = row[:seq] - rand(1..3)
          when 2
            row[:timestamp] = row[:timestamp] - 86_400
          when 3
            row[:price_quote_per_base] = -100
          when 4
            row[:quantity_base] = 0
          when 5
            row[:trade_id] = trades.sample[:trade_id]
          when 6
            row[:market_id] = "BTC-ARS-X"
          end

          row[:invalid] = true
        end
      end

      def write_excel(file_path, trades)
        package = Axlsx::Package.new
        workbook = package.workbook

        styles = workbook.styles
        header_style = styles.add_style(b: true)
        normal_style = styles.add_style
        error_style = styles.add_style(bg_color: "FFCC99", fg_color: "000000")

        workbook.add_worksheet(name: "Trades") do |sheet|
          sheet.add_row(HEADERS, style: header_style)

          trades.each do |trade|
            style = trade[:invalid] ? error_style : normal_style
            sheet.add_row(
              HEADERS.map { |key| trade[key.to_sym] },
              style: Array.new(HEADERS.length, style)
            )
          end
        end

        package.serialize(file_path)
      end
    end
  end
end
