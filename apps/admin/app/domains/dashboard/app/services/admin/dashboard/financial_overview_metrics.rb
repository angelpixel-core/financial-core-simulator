require "bigdecimal"
require "json"

module Admin
  module Dashboard
    class FinancialOverviewMetrics
      REQUIRED_FIELDS = %w[timestamp quantity price].freeze
      SYMBOL_DELIMITERS = ['/', '-', '_'].freeze

      def initialize(run:, account_id: nil, market_id: nil)
        @run = run
        @account_id = normalize_filter_value(account_id)
        @market_id = normalize_filter_value(market_id)
      end

      def call
        trades = filtered_trades
        pnl_daily = PnlTimelineAggregator.new(points: filtered_timeline_points).call

        {
          trade_activity: trade_activity(trades),
          trade_volume: trade_volume(trades),
          pnl_daily: pnl_daily
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
          quantity = parse_decimal(trade_field(trade, "quantityBase") || trade_field(trade, "quantity"))
          price = parse_decimal(trade_field(trade, "priceQuotePerBase") || trade_field(trade, "price"))
          symbol = trade_field(trade, "marketId") || trade_field(trade, "symbol")
          account_id = trade_field(trade, "accountId")
          market_id = trade_field(trade, "marketId") || symbol

          next if timestamp.nil? || quantity.nil? || price.nil?
          next if quantity <= 0 || price <= 0
          next if @account_id && account_id.to_s != @account_id
          next if @market_id && market_id.to_s != @market_id

          {
            timestamp: timestamp,
            quantity: quantity,
            price: price,
            symbol: symbol
          }
        end
      end

      def filtered_timeline_points
        points = timeline_points
        return [] if points.empty?

        points.select do |point|
          next false unless point.is_a?(Hash)

          account_id = point['account_id'] || point[:account_id] || point['accountId'] || point[:accountId]
          market_id = point['market_id'] || point[:market_id] || point['marketId'] || point[:marketId]

          next false if @account_id && account_id.to_s != @account_id
          next false if @market_id && market_id.to_s != @market_id

          true
        end
      end

      def timeline_points
        payload = result_payload
        return [] if payload.nil?

        timeline = payload.dig("timeline", "points")
        timeline.is_a?(Array) ? timeline : []
      end

      def result_payload
        return nil if @run.nil?

        path = @run.result_json_path
        return nil if path.blank?
        return nil unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        nil
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
        time = parse_time(raw)
        return nil if time.nil?

        time.utc.to_date.iso8601
      end

      def parse_time(raw)
        return nil if raw.nil?

        return Time.at(normalize_epoch(raw)).utc if raw.is_a?(Numeric)

        raw_string = raw.to_s.strip
        return nil if raw_string.empty?

        return Time.at(normalize_epoch(raw_string.to_i)).utc if raw_string.match?(/\A\d+\z/)

        parsed = Time.zone.parse(raw_string)
        return nil if parsed.nil?

        parsed
      rescue ArgumentError
        nil
      end

      def normalize_epoch(value)
        numeric_value = value.to_f
        return numeric_value / 1000.0 if numeric_value >= 1_000_000_000_000

        numeric_value
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

      def normalize_filter_value(value)
        normalized = value.to_s.strip
        return nil if normalized.empty?

        normalized
      end
    end
  end
end
