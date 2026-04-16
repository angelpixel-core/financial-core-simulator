require 'bigdecimal'
require 'json'

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
        persisted = persisted_metrics
        return persisted if persisted

        trades = filtered_trades
        trade_volume_points = trade_volume(trades)
        pnl_daily = PnlTimelineAggregator.new(points: filtered_timeline_points).call

        if apply_daily_fx?
          fx_map = build_fx_map(trade_volume_points, pnl_daily)
          trade_volume_points = apply_daily_fx_to_trade_volume(trade_volume_points, fx_map)
          pnl_daily = apply_daily_fx_to_pnl(pnl_daily, fx_map)
        else
          pnl_daily = apply_fx_to_pnl(pnl_daily)
        end

        {
          trade_activity: trade_activity(trades),
          trade_volume: trade_volume_points,
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

      def persisted_metrics
        return nil unless @account_id.nil? && @market_id.nil?
        return nil if @run.nil?

        snapshots = RunSnapshot.for_timeline_eligible_runs(
          up_to_run_id: @run.id,
          reporting_currency: reporting_currency_value
        )
        return nil if snapshots.empty?

        {
          trade_activity: persisted_trade_activity(snapshots),
          trade_volume: persisted_trade_volume(snapshots),
          pnl_daily: persisted_pnl_daily(snapshots)
        }
      end

      def persisted_trade_activity(snapshots)
        aggregate_snapshots_by_date(snapshots) do |entry, snapshot|
          volume = snapshot.run_daily_volume
          next if volume.nil?

          entry[:trade_count] += volume.trade_count
        end.map { |entry| { timestamp: entry[:timestamp], trade_count: entry[:trade_count] } }
      end

      def persisted_trade_volume(snapshots)
        aggregate_snapshots_by_date(snapshots) do |entry, snapshot|
          volume = snapshot.run_daily_volume
          next if volume.nil?

          entry[:volume] += volume.notional_volume.to_f
          entry[:unit_type] ||= volume.unit_type
          entry[:unit_code] ||= volume.unit_code
        end.filter_map do |entry|
          next if entry[:unit_type].nil? || entry[:unit_code].nil?

          {
            timestamp: entry[:timestamp],
            volume: entry[:volume],
            unit_type: entry[:unit_type],
            unit_code: entry[:unit_code]
          }
        end
      end

      def persisted_pnl_daily(snapshots)
        aggregate_snapshots_by_date(snapshots) do |entry, snapshot|
          pnl = snapshot.run_daily_pnl
          next if pnl.nil?

          entry[:realized_pnl] += pnl.realized_pnl.to_f
          entry[:unrealized_pnl] += pnl.unrealized_pnl.to_f
          entry[:total_pnl] += pnl.total_pnl.to_f
        end.map do |entry|
          {
            timestamp: entry[:timestamp],
            realized_pnl: entry[:realized_pnl],
            unrealized_pnl: entry[:unrealized_pnl],
            total_pnl: entry[:total_pnl]
          }
        end
      end

      def aggregate_snapshots_by_date(snapshots)
        grouped = snapshots.group_by(&:operational_date)

        grouped.keys.sort.map do |date|
          entry = {
            timestamp: date.iso8601,
            trade_count: 0,
            volume: 0.0,
            unit_type: nil,
            unit_code: nil,
            realized_pnl: 0.0,
            unrealized_pnl: 0.0,
            total_pnl: 0.0
          }

          grouped.fetch(date).each do |snapshot|
            yield(entry, snapshot)
          end

          entry
        end
      end

      def filtered_trades
        input_trades.filter_map do |trade|
          next unless trade.is_a?(Hash)
          next unless trade_valid?(trade)

          timestamp = normalize_timestamp(trade_field(trade, 'timestamp'))
          quantity = parse_decimal(trade_field(trade, 'quantityBase') || trade_field(trade, 'quantity'))
          price = parse_decimal(trade_field(trade, 'priceQuotePerBase') || trade_field(trade, 'price'))
          symbol = trade_field(trade, 'marketId') || trade_field(trade, 'symbol')
          account_id = trade_field(trade, 'accountId')
          market_id = trade_field(trade, 'marketId') || symbol

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

        timeline = payload.dig('timeline', 'points')
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

        rate = apply_daily_fx? ? nil : fx_rate_multiplier
        reporting_currency = rate.nil? ? nil : reporting_currency_value

        grouped = trades.group_by { |trade| trade[:timestamp] }

        grouped.keys.sort.map do |timestamp|
          sum = grouped.fetch(timestamp).sum { |trade| trade[:quantity] * trade[:price] }
          sum *= rate if rate

          {
            timestamp: timestamp,
            volume: sum.to_f,
            unit_type: unit.fetch(:unit_type),
            unit_code: reporting_currency || unit.fetch(:unit_code)
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

      def apply_fx_to_pnl(pnl_daily)
        rate = fx_rate_multiplier
        return pnl_daily if rate.nil?

        pnl_daily.map do |entry|
          next entry unless entry.is_a?(Hash)

          realized = parse_decimal(entry[:realized_pnl] || entry['realized_pnl'])
          unrealized = parse_decimal(entry[:unrealized_pnl] || entry['unrealized_pnl'])
          total = parse_decimal(entry[:total_pnl] || entry['total_pnl'])

          next entry if realized.nil? || unrealized.nil? || total.nil?

          {
            timestamp: entry[:timestamp] || entry['timestamp'],
            realized_pnl: (realized * rate).to_f,
            unrealized_pnl: (unrealized * rate).to_f,
            total_pnl: (total * rate).to_f
          }
        end
      end

      def apply_daily_fx_to_trade_volume(points, fx_map)
        base_currency = Admin::Fx::RateResolver::BASE_CURRENCY
        reporting_currency = reporting_currency_value

        points.map do |point|
          next point unless point.is_a?(Hash)

          timestamp = point[:timestamp] || point['timestamp']
          operational_date = operational_date_for(timestamp)
          fx_entry = fx_entry_for(fx_map, operational_date)

          volume = parse_decimal(point[:volume] || point['volume'])
          if fx_entry[:missing] || volume.nil?
            converted_volume = volume.nil? ? point[:volume] || point['volume'] : volume.to_f
            unit_code = base_currency
          else
            converted_volume = (volume * fx_entry[:rate]).to_f
            unit_code = reporting_currency
          end

          {
            timestamp: timestamp,
            volume: converted_volume,
            unit_type: point[:unit_type] || point['unit_type'],
            unit_code: unit_code,
            fx_rate: fx_entry[:rate_payload],
            fx_rate_date: fx_entry[:rate_date]&.iso8601,
            fx_missing: fx_entry[:missing]
          }
        end
      end

      def apply_daily_fx_to_pnl(points, fx_map)
        points.map do |entry|
          next entry unless entry.is_a?(Hash)

          timestamp = entry[:timestamp] || entry['timestamp']
          operational_date = operational_date_for(timestamp)
          fx_entry = fx_entry_for(fx_map, operational_date)

          realized = parse_decimal(entry[:realized_pnl] || entry['realized_pnl'])
          unrealized = parse_decimal(entry[:unrealized_pnl] || entry['unrealized_pnl'])
          total = parse_decimal(entry[:total_pnl] || entry['total_pnl'])

          if fx_entry[:missing] || realized.nil? || unrealized.nil? || total.nil?
            realized_value = realized.nil? ? entry[:realized_pnl] || entry['realized_pnl'] : realized.to_f
            unrealized_value = unrealized.nil? ? entry[:unrealized_pnl] || entry['unrealized_pnl'] : unrealized.to_f
            total_value = total.nil? ? entry[:total_pnl] || entry['total_pnl'] : total.to_f
          else
            realized_value = (realized * fx_entry[:rate]).to_f
            unrealized_value = (unrealized * fx_entry[:rate]).to_f
            total_value = (total * fx_entry[:rate]).to_f
          end

          {
            timestamp: timestamp,
            realized_pnl: realized_value,
            unrealized_pnl: unrealized_value,
            total_pnl: total_value,
            fx_rate: fx_entry[:rate_payload],
            fx_rate_date: fx_entry[:rate_date]&.iso8601,
            fx_missing: fx_entry[:missing]
          }
        end
      end

      def apply_daily_fx?
        reporting_currency = reporting_currency_value
        reporting_currency.present? && reporting_currency != Admin::Fx::RateResolver::BASE_CURRENCY
      end

      def build_fx_map(*series)
        reporting_currency = reporting_currency_value
        return {} if reporting_currency.blank?

        dates = series.flat_map { |points| collect_operational_dates(points) }.uniq
        return {} if dates.empty?

        base_currency = Admin::Fx::RateResolver::BASE_CURRENCY

        rates = FxDailyRate.where(
          operational_date: dates,
          base_currency: base_currency,
          quote_currency: reporting_currency
        )
        rates_by_date = rates.index_by(&:operational_date)

        gaps = FxRateGap.open_status.where(
          operational_date: dates,
          base_currency: base_currency,
          quote_currency: reporting_currency
        )
        gaps_by_date = gaps.index_by(&:operational_date)

        dates.each_with_object({}) do |date, acc|
          rate_record = rates_by_date[date]
          gap = gaps_by_date[date]
          missing = gap.present? || rate_record.nil? || rate_record.rate.nil? || rate_record.source == 'placeholder'
          rate_value = missing || rate_record.nil? ? nil : parse_decimal(rate_record.rate)

          acc[date] = {
            rate: rate_value,
            rate_payload: rate_value&.to_s('F'),
            missing: missing,
            rate_date: date
          }
        end
      end

      def collect_operational_dates(points)
        Array(points).filter_map do |point|
          next unless point.is_a?(Hash)

          timestamp = point[:timestamp] || point['timestamp']
          operational_date_for(timestamp)
        end
      end

      def operational_date_for(timestamp)
        return nil if timestamp.blank?

        return timestamp if timestamp.is_a?(Date)

        return Date.iso8601(timestamp) if timestamp.is_a?(String) && timestamp.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        Admin::Fx::OperationalDate.call(timestamp: timestamp)
      rescue ArgumentError
        nil
      end

      def fx_entry_for(fx_map, operational_date)
        entry = operational_date.nil? ? nil : fx_map[operational_date]

        return entry if entry

        {
          rate: nil,
          rate_payload: nil,
          missing: true,
          rate_date: operational_date
        }
      end

      def fx_rate_multiplier
        context = fx_context
        return nil unless context

        rate_missing = cast_boolean(context_value(context, 'rateMissing', :rateMissing, 'rate_missing', :rate_missing))
        rate_value = context_value(context, 'rate', :rate)
        return nil if rate_missing || rate_value.blank?

        rate = parse_decimal(rate_value)
        return nil if rate.nil? || rate == 1

        rate
      end

      def reporting_currency_value
        context = fx_context
        return ReportingSetting.current.reporting_currency unless context

        value = context_value(context, 'reportingCurrency', :reportingCurrency, 'reporting_currency',
                              :reporting_currency)
        value = value.to_s.strip.presence
        return value if value.present?

        ReportingSetting.current.reporting_currency
      end

      def fx_context
        return nil if @run.nil?

        run_context = normalize_fx_context(@run.fx_context)
        input_context = nil
        input_context = normalize_fx_context(@run.input_json['fxContext']) if @run.input_json.is_a?(Hash)

        return run_context if context_has_rate_data?(run_context)

        return input_context if context_has_rate_data?(input_context)

        return run_context if context_has_reporting_currency?(run_context)

        return input_context if context_has_reporting_currency?(input_context)

        run_context || input_context
      end

      def normalize_fx_context(raw)
        return nil if raw.nil?
        return raw if raw.is_a?(Hash)
        return JSON.parse(raw) if raw.is_a?(String)

        nil
      rescue JSON::ParserError
        nil
      end

      def context_has_fx_data?(context)
        return false unless context.is_a?(Hash)

        context_has_rate_data?(context) || context_has_reporting_currency?(context)
      end

      def context_has_rate_data?(context)
        return false unless context.is_a?(Hash)

        rate_value = context_value(context, 'rate', :rate)
        rate_missing = context_value(context, 'rateMissing', :rateMissing, 'rate_missing', :rate_missing)

        rate_value.present? || !rate_missing.nil?
      end

      def context_has_reporting_currency?(context)
        return false unless context.is_a?(Hash)

        reporting_currency = context_value(context, 'reportingCurrency', :reportingCurrency, 'reporting_currency',
                                           :reporting_currency)

        reporting_currency.to_s.strip.present?
      end

      def context_value(context, *keys)
        return nil unless context.is_a?(Hash)

        keys.each do |key|
          return context[key] if context.key?(key)
        end

        nil
      end

      def cast_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def trade_field(trade, key)
        trade[key] || trade[key.to_sym]
      end

      def trade_valid?(trade)
        valid = trade_field(trade, 'valid')
        return false if valid == false

        trade_id = trade_id_for(trade)
        return false if trade_id && invalid_trade_ids.include?(trade_id)

        true
      end

      def trade_id_for(trade)
        raw = trade_field(trade, 'tradeId') || trade_field(trade, 'trade_id')
        value = raw.to_s.strip
        value.empty? ? nil : value
      end

      def invalid_trade_ids
        return Set.new if @run.nil?

        @invalid_trade_ids ||= begin
          ids = @run.run_validation_errors.where.not(trade_id: [nil, '']).pluck(:trade_id)
          Set.new(ids.compact.map { |id| id.to_s })
        end
      end

      def normalize_filter_value(value)
        normalized = value.to_s.strip
        return nil if normalized.empty?

        normalized
      end
    end
  end
end
