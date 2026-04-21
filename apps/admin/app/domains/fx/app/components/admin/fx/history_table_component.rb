# frozen_string_literal: true

module Admin
  module Fx
    class HistoryTableComponent < ViewComponent::Base
      def initialize(dates:, supported_pairs:, rates_by_pair:, role:, sort_order:, navigation_context:, source_id: nil,
        selected_source: nil, fx_sources: [], selected_market: nil, sync_poll: false, available_markets: [], latest_upload: nil,
        upload_status_stream: nil, latest_ingestions: {}, rate_lineage: {})
        @dates = dates
        @supported_pairs = supported_pairs
        @rates_by_pair = rates_by_pair
        @role = role
        @sort_order = sort_order
        @navigation_context = navigation_context
        @source_id = source_id
        @selected_source = selected_source
        @fx_sources = fx_sources
        @selected_market = selected_market
        @sync_poll = sync_poll
        @available_markets = available_markets
        @latest_upload = latest_upload
        @upload_status_stream = upload_status_stream
        @latest_ingestions = latest_ingestions
        @rate_lineage = rate_lineage
      end

      def pair_labels
        supported_pairs.map do |base_currency, quote_currency|
          ["#{base_currency}/#{quote_currency}", base_currency, quote_currency]
        end
      end

      def rate_for(date, pair_label)
        rates_by_pair.fetch(pair_label, {})[date]
      end

      def lineage_for(rate)
        return {} if rate.blank?

        rate_lineage[rate.id] || {}
      end

      def editable_rate?(rate)
        %w[operator admin].include?(role) && (rate.nil? || rate.manual? || rate.placeholder?)
      end

      def gap_status(rate)
        return nil unless rate&.placeholder?

        gap = rate.placeholder_gap || FxRateGap.open_for(
          operational_date: rate.operational_date,
          base_currency: rate.base_currency,
          quote_currency: rate.quote_currency
        )
        gap&.status
      end

      def display_rate(rate)
        return t("admin.fx.history.placeholder_value") if rate.nil? || rate.rate.nil?

        helpers.truncate_fiat(rate.rate, rate.quote_currency)
      end

      def sort_label
        t("admin.fx.history.table.sort_#{sort_order}")
      end

      def toggle_sort_order
        (sort_order == "asc") ? "desc" : "asc"
      end

      def can_operate?
        %w[operator admin].include?(role)
      end

      def selected_source_id
        selected_source&.id
      end

      def selected_source_name
        selected_source&.name
      end

      def sync_ready?
        selected_source_id.present? && selected_market.present?
      end

      def sync_in_progress?
        %w[pending running].include?(selected_ingestion&.status)
      end

      def selected_ingestion
        return nil if selected_source_id.blank?

        latest_ingestions[selected_source_id]
      end

      def market_select_options
        available_markets.map { |market| [format_market_label(market), market] }
      end

      def source_select_options
        [[I18n.t("admin.fx.history.filter.all_sources"), ""]] + fx_sources.map { |source| [source.name, source.id] }
      end

      def usd_market_charts
        @usd_market_charts ||= usd_market_series
      end

      def usd_market_charts?
        return false if usd_market_series.empty?

        usd_chart_points.any? do |point|
          usd_market_series.any? { |series| point[series[:key]].present? }
        end
      end

      def usd_market_series
        @usd_market_series ||= begin
          palette = ["#38bdf8", "#a78bfa", "#22c55e", "#f59e0b", "#f97316", "#e879f9"]
          candidate_currencies.each_with_index.filter_map do |currency, index|
            key = market_key(currency)
            points = usd_chart_points.map { |point| point[key] }.compact
            next if points.empty?

            {
              key: key,
              label: "#{currency}/USD",
              color: palette[index % palette.length]
            }
          end
        end
      end

      def usd_chart_points
        @usd_chart_points ||= dates.map do |date|
          point = {
            label: I18n.l(date),
            timestamp: date.iso8601
          }

          candidate_currencies.each do |currency|
            point[market_key(currency)] = usd_value_for(currency: currency, date: date)
          end

          point
        end
      end

      attr_reader :dates, :supported_pairs, :rates_by_pair, :role, :sort_order, :navigation_context, :source_id,
        :selected_source, :fx_sources, :selected_market, :sync_poll, :available_markets, :latest_upload, :upload_status_stream,
        :latest_ingestions, :rate_lineage

      private

      def candidate_currencies
        @candidate_currencies ||= supported_pairs.flatten.map(&:upcase).uniq - ["USD"]
      end

      def market_key(currency)
        "#{currency.downcase}_usd"
      end

      def format_market_label(market)
        normalized = market.to_s.upcase.gsub(/[^A-Z]/, "")
        return market if normalized.length != 6

        "#{normalized[0, 3]}/#{normalized[3, 3]}"
      end

      def usd_value_for(currency:, date:)
        direct_value = rate_value(base_currency: currency, quote_currency: "USD", date: date)
        return direct_value if direct_value.present?

        inverse_value = rate_value(base_currency: "USD", quote_currency: currency, date: date)
        if inverse_value.present?
          inverse = inverse_value.to_f
          return (1.0 / inverse) if inverse.positive?
        end

        base_ars = rate_value(base_currency: currency, quote_currency: "ARS", date: date)
        usd_ars = rate_value(base_currency: "USD", quote_currency: "ARS", date: date)
        return nil if base_ars.blank? || usd_ars.blank?

        usd_ars_value = usd_ars.to_f
        return nil unless usd_ars_value.positive?

        base_ars.to_f / usd_ars_value
      end

      def rate_value(base_currency:, quote_currency:, date:)
        pair = rates_by_pair.fetch("#{base_currency}/#{quote_currency}", {})
        pair[date]&.rate
      end

    end
  end
end
