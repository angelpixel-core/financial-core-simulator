require 'bigdecimal'

module Admin
  module Dashboard
    class FinancialOverviewMetrics
      REQUIRED_FIELDS = %w[timestamp quantity price].freeze
      SYMBOL_DELIMITERS = ['/', '-', '_'].freeze

      def initialize(run:)
        @run = run
      end

      def call
        trades = filtered_trades

        {
          trade_activity: trade_activity(trades),
          trade_volume: trade_volume(trades)
        }
      end

      private

      def input_trades
        input_json = @run&.input_json
        return [] unless input_json.is_a?(Hash)

        trades = input_json['trades']
        return [] unless trades.is_a?(Array)

        trades
      end

      def filtered_trades
        input_trades.filter_map do |trade|
          next unless trade.is_a?(Hash)

          timestamp = normalize_timestamp(trade_field(trade, 'timestamp'))
          quantity = parse_decimal(trade_field(trade, 'quantity'))
          price = parse_decimal(trade_field(trade, 'price'))

          next if timestamp.nil? || quantity.nil? || price.nil?
          next if quantity <= 0 || price <= 0

          {
            timestamp: timestamp,
            quantity: quantity,
            price: price,
            symbol: trade_field(trade, 'symbol')
          }
        end
      end

      def trade_activity(trades)
        grouped = trades.group_by { |trade| trade[:timestamp] }
        grouped.keys.sort.map do |timestamp|
          {
            timestamp: timestamp,
            trade_count: grouped.fetch(timestamp).length
          }
        end
      end

      def trade_volume(trades)
        return [] if trades.empty?

        unit = resolve_unit(trades)
        return [] if unit.nil?

        grouped = trades.group_by { |trade| trade[:timestamp] }

        grouped.keys.sort.map do |timestamp|
          sum = grouped.fetch(timestamp).sum { |trade| trade[:quantity] * trade[:price] }

          {
            timestamp: timestamp,
            volume: sum.to_f,
            unit_type: unit.fetch(:unit_type),
            unit_code: unit.fetch(:unit_code)
          }
        end
      end

      def resolve_unit(trades)
        units = trades.map { |trade| unit_from_symbol(trade[:symbol]) }
        return nil if units.any?(nil)

        quote_codes = units.map { |unit| unit[:unit_code] }.uniq
        return nil unless quote_codes.length == 1

        {
          unit_type: 'quote',
          unit_code: quote_codes.first
        }
      end

      def unit_from_symbol(symbol)
        symbol_string = symbol.to_s.strip
        return nil if symbol_string.empty?

        delimiter = SYMBOL_DELIMITERS.find { |entry| symbol_string.include?(entry) }
        return nil if delimiter.nil?

        base, quote = symbol_string.split(delimiter, 2).map { |value| value.to_s.strip }
        return nil if base.empty? || quote.empty?

        { unit_code: quote }
      end

      def normalize_timestamp(raw)
        return nil if raw.nil?

        parsed = Time.zone.parse(raw.to_s)
        return nil if parsed.nil?

        parsed.utc.iso8601
      rescue ArgumentError
        nil
      end

      def parse_decimal(value)
        return nil if value.nil?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end

      def trade_field(trade, key)
        trade[key] || trade[key.to_sym]
      end
    end
  end
end
