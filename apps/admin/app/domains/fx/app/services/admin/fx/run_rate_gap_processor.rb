# frozen_string_literal: true

module Admin
  module Fx
    class RunRateGapProcessor
      SYMBOL_DELIMITERS = ["/", "-", "_"].freeze
      SUPPORTED_PAIRS = [
        %w[USD ARS],
        %w[BTC USD],
        %w[BTC ARS],
        %w[ETH USD],
        %w[ETH ARS]
      ].freeze

      def self.call(run:)
        new.call(run: run)
      end

      def initialize(gap_repository: Admin::Fx::Gaps::Repository.new)
        @gap_repository = gap_repository
      end

      def call(run:)
        return if run.nil?

        input = run.input_json.is_a?(Hash) ? run.input_json : {}
        operational_dates = operational_dates_from(input)
        return if operational_dates.empty?

        pairs = supported_pairs_from(input)
        return if pairs.empty?

        operational_dates.each do |operational_date|
          pairs.each do |base_currency, quote_currency|
            rate = Admin::Fx::RateUpserter.call(
              operational_date: operational_date,
              base_currency: base_currency,
              quote_currency: quote_currency,
              rate: nil,
              source: "placeholder",
              source_run_id: run.id,
              created_context: {source: "run"},
              enforce_operational_date: false
            )

            next unless rate.placeholder?

            gap = @gap_repository.open_for(
              operational_date: operational_date,
              base_currency: base_currency,
              quote_currency: quote_currency
            )
            next if gap.present?

            @gap_repository.create_open!(
              operational_date: operational_date,
              base_currency: base_currency,
              quote_currency: quote_currency,
              placeholder_rate_id: rate.id,
              source_run_id: run.id,
              source_upload_id: nil,
              created_context: {source: "run"}
            )
          end
        end
      end

      private

      def operational_dates_from(input)
        dates = []
        trades = Array(input["trades"] || input[:trades])
        trades.each do |trade|
          next unless trade.is_a?(Hash)

          timestamp = trade["timestamp"] || trade[:timestamp]
          date = operational_date_for(timestamp)
          dates << date if date
        end

        timeline = input["timeline"] || input[:timeline]
        events = timeline.is_a?(Hash) ? Array(timeline["events"] || timeline[:events]) : []
        events.each do |event|
          next unless event.is_a?(Hash)

          timestamp = event["timestamp"] || event[:timestamp]
          date = operational_date_for(timestamp)
          dates << date if date
        end

        dates.compact.uniq
      end

      def supported_pairs_from(input)
        detected_pairs = market_pairs_from(input)

        variants = detected_pairs.flat_map do |base_currency, quote_currency|
          base = base_currency.to_s.upcase
          quote = quote_currency.to_s.upcase
          pairs = [[base, quote]]
          next pairs if quote == "ARS"

          pairs << [base, "ARS"] unless base == "ARS"
          pairs << %w[USD ARS] if quote == "USD"
          pairs
        end

        supported = SUPPORTED_PAIRS.map { |pair| pair.map(&:upcase) }
        variants
          .map { |pair| pair.map { |value| value.to_s.upcase } }
          .uniq
          .select { |pair| supported.include?(pair) }
      end

      def market_pairs_from(input)
        markets = Array(input["markets"] || input[:markets]).filter_map do |market|
          market_id = market.is_a?(Hash) ? (market["marketId"] || market[:marketId]) : market
          market_id.to_s.strip.presence
        end

        trades = Array(input["trades"] || input[:trades]).filter_map do |trade|
          next unless trade.is_a?(Hash)

          market_id = trade["marketId"] || trade[:marketId] || trade["symbol"] || trade[:symbol]
          market_id.to_s.strip.presence
        end

        (markets + trades).uniq.filter_map { |market_id| parse_pair(market_id) }
      end

      def parse_pair(market_id)
        return nil if market_id.blank?

        delimiter = SYMBOL_DELIMITERS.find { |entry| market_id.include?(entry) }
        return nil if delimiter.nil?

        base_currency, quote_currency = market_id.split(delimiter, 2).map { |value| value.to_s.strip }
        return nil if base_currency.empty? || quote_currency.empty?

        [base_currency.upcase, quote_currency.upcase]
      end

      def operational_date_for(timestamp)
        return nil if timestamp.nil?

        Admin::Fx::OperationalDate.call(timestamp: timestamp)
      rescue ArgumentError
        nil
      end
    end
  end
end
