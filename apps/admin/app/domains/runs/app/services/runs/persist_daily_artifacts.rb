# frozen_string_literal: true

require 'bigdecimal'
require 'json'

module Runs
  class PersistDailyArtifacts
    SYMBOL_DELIMITERS = ['/', '-', '_'].freeze

    def self.call(run:, payload: nil)
      new.call(run: run, payload: payload)
    end

    def call(run:, payload: nil)
      return if run.nil?

      resolved_payload = result_payload(run, payload: payload)
      return if resolved_payload.nil?

      reporting_currency = resolve_reporting_currency(run)
      input = run.input_json.is_a?(Hash) ? run.input_json : {}
      @invalid_trade_ids = invalid_trade_ids_for(run)

      persist_pnls(run, reporting_currency, resolved_payload)
      persist_volumes(run, reporting_currency, input)
      persist_events(run, reporting_currency, input)
    end

    private

    def result_payload(run, payload: nil)
      return payload if payload.is_a?(Hash)

      path = run.result_json_path
      return nil if path.blank? || !File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    def resolve_reporting_currency(run)
      context = normalize_fx_context(run.fx_context)
      return context['reportingCurrency'] if context.is_a?(Hash) && context['reportingCurrency'].present?

      input_context = normalize_fx_context(run.input_json['fxContext']) if run.input_json.is_a?(Hash)
      if input_context.is_a?(Hash) && input_context['reportingCurrency'].present?
        return input_context['reportingCurrency']
      end

      ReportingSetting.current.reporting_currency
    end

    def normalize_fx_context(raw)
      return nil if raw.nil?
      return raw if raw.is_a?(Hash)
      return JSON.parse(raw) if raw.is_a?(String)

      nil
    rescue JSON::ParserError
      nil
    end

    def persist_pnls(run, reporting_currency, payload)
      points = payload.dig('timeline', 'points')
      return unless points.is_a?(Array)

      pnl_daily = Admin::Dashboard::PnlTimelineAggregator.new(points: points).call
      pnl_daily.each do |entry|
        date = entry[:timestamp] || entry['timestamp']
        next if date.blank?

        snapshot = find_or_create_snapshot(run, reporting_currency, date)
        next if snapshot.nil?

        record = RunDailyPnl.find_or_initialize_by(run_snapshot_id: snapshot.id)
        record.assign_attributes(
          realized_pnl: BigDecimal(entry[:realized_pnl].to_s),
          unrealized_pnl: BigDecimal(entry[:unrealized_pnl].to_s),
          total_pnl: BigDecimal(entry[:total_pnl].to_s)
        )
        record.save!
      end
    end

    def persist_volumes(run, reporting_currency, input)
      trades = normalized_trades(input)
      return if trades.empty?

      unit = resolve_unit(trades)
      return if unit.nil?

      rate = fx_rate_multiplier(run)
      unit_code = rate.nil? ? unit.fetch(:unit_code) : reporting_currency

      grouped = trades.group_by { |trade| trade.fetch(:operational_date) }
      grouped.each do |date, day_trades|
        snapshot = find_or_create_snapshot(run, reporting_currency, date)
        next if snapshot.nil?

        sum = day_trades.sum { |trade| trade.fetch(:quantity) * trade.fetch(:price) }
        sum *= rate if rate

        record = RunDailyVolume.find_or_initialize_by(run_snapshot_id: snapshot.id)
        record.assign_attributes(
          notional_volume: sum,
          trade_count: day_trades.length,
          unit_type: unit.fetch(:unit_type),
          unit_code: unit_code
        )
        record.save!
      end
    end

    def persist_events(run, reporting_currency, input)
      timeline = input['timeline'] || input[:timeline]
      events = timeline.is_a?(Hash) ? Array(timeline['events'] || timeline[:events]) : []
      return if events.empty?

      events.each_with_index do |event, index|
        next unless event.is_a?(Hash)

        event_type = event['eventType'] || event[:eventType] || event['event_type'] || event[:event_type]
        next if event_type.blank?

        if event_type == 'TRADE_APPLIED'
          trade = event['trade'] || event[:trade]
          next unless trade_valid?(trade)
        end

        timestamp = event['timestamp'] || event[:timestamp]
        date = operational_date_for(timestamp)
        next if date.nil?

        snapshot = find_or_create_snapshot(run, reporting_currency, date)
        next if snapshot.nil?

        payload = event.is_a?(Hash) ? event : nil
        next if payload.nil? || payload.empty?

        seq = event['timelineSeq'] || event[:timelineSeq] || event['eventSeq'] || event[:eventSeq] || (index + 1)
        record = RunDailyEvent.find_or_initialize_by(run_snapshot_id: snapshot.id, event_seq: seq)
        record.assign_attributes(
          event_type: event_type,
          payload: payload
        )
        record.save!
      end
    end

    def find_or_create_snapshot(run, reporting_currency, date)
      operational_date = date.is_a?(Date) ? date : Date.iso8601(date.to_s)
      RunSnapshot.find_or_create_by!(
        run_id: run.id,
        operational_date: operational_date,
        reporting_currency: reporting_currency
      )
    rescue ArgumentError
      nil
    end

    def normalized_trades(input)
      trades = Array(input['trades'] || input[:trades])
      trades.filter_map do |trade|
        next unless trade.is_a?(Hash)
        next unless trade_valid?(trade)

        timestamp = trade['timestamp'] || trade[:timestamp]
        time = parse_time(timestamp)
        next if time.nil?

        quantity = parse_decimal(trade['quantityBase'] || trade[:quantityBase] || trade['quantity'] || trade[:quantity])
        price = parse_decimal(trade['priceQuotePerBase'] || trade[:priceQuotePerBase] || trade['price'] || trade[:price])
        symbol = trade['marketId'] || trade[:marketId] || trade['symbol'] || trade[:symbol]

        next if quantity.nil? || price.nil?
        next if quantity <= 0 || price <= 0

        {
          operational_date: Admin::Fx::OperationalDate.call(timestamp: time),
          quantity: quantity,
          price: price,
          symbol: symbol
        }
      end
    end

    def trade_valid?(trade)
      return false unless trade.is_a?(Hash)

      valid = trade['valid']
      valid = trade[:valid] if valid.nil?
      return false if valid == false

      trade_id = trade_id_for(trade)
      return false if trade_id && invalid_trade_ids.include?(trade_id)

      true
    end

    def trade_id_for(trade)
      raw = trade['tradeId'] || trade[:tradeId] || trade['trade_id'] || trade[:trade_id]
      value = raw.to_s.strip
      value.empty? ? nil : value
    end

    def invalid_trade_ids_for(run)
      ids = run.run_validation_errors.where.not(trade_id: [nil, '']).pluck(:trade_id)
      Set.new(ids.compact.map { |id| id.to_s })
    end

    def invalid_trade_ids
      @invalid_trade_ids ||= Set.new
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

    def parse_time(raw)
      return nil if raw.nil?

      return Time.at(normalize_epoch(raw)).utc if raw.is_a?(Numeric)

      raw_string = raw.to_s.strip
      return nil if raw_string.empty?

      return Time.at(normalize_epoch(raw_string.to_i)).utc if raw_string.match?(/\A\d+\z/)

      Time.zone.parse(raw_string)
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

    def fx_rate_multiplier(run)
      context = normalize_fx_context(run.fx_context)
      return nil unless context.is_a?(Hash)

      rate_missing = ActiveModel::Type::Boolean.new.cast(context['rateMissing'] || context[:rateMissing] ||
        context['rate_missing'] || context[:rate_missing])
      rate_value = context['rate'] || context[:rate]
      return nil if rate_missing || rate_value.blank?

      rate = parse_decimal(rate_value)
      return nil if rate.nil? || rate == 1

      rate
    end

    def operational_date_for(timestamp)
      Admin::Fx::OperationalDate.call(timestamp: timestamp)
    rescue ArgumentError
      nil
    end
  end
end
