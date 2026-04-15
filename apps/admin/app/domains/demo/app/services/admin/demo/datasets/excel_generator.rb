# frozen_string_literal: true

require "caxlsx"
require "fileutils"
require "securerandom"
require "time"

module Admin
  module Demo
    module Datasets
      class ExcelGenerator
        DAYS = 30
        TRADES_PER_DAY_RANGE = (3..8)
        ERROR_RATE = 0.08
        ACCOUNT_COUNT_RANGE = (2..5)
        MARKETS = ["ETH-USD"].freeze

        HEADERS = %w[
          trade_id account_id market_id timestamp seq
          side quantity_base price_quote_per_base
        ].freeze

        def initialize(output_dir:)
          @output_dir = output_dir
          @accounts = build_accounts
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
          end_date = Time.zone.today - 1
          start_date = end_date - (DAYS - 1)

          DAYS.times do |day|
            date = start_date + day
            date_time = date.to_time(:utc)
            trades_per_day = rand(TRADES_PER_DAY_RANGE)
            timestamps = Array.new(trades_per_day) { rand(0..86_399) }.sort

            timestamps.each do |offset|
              account_id = @accounts.sample
              market_id = MARKETS.sample
              key = "#{account_id}|#{market_id}"
              side = (inventories[key] <= 0) ? "BUY" : %w[BUY SELL].sample
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
                timestamp: (date_time + offset).to_i,
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

        def build_accounts
          count = rand(ACCOUNT_COUNT_RANGE)
          Array.new(count) { |index| "acc-#{index + 1}" }
        end
      end
    end
  end
end
