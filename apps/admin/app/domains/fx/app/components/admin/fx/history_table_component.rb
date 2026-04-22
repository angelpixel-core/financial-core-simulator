# frozen_string_literal: true

module Admin
  module Fx
    class HistoryTableComponent < ViewComponent::Base
      def initialize(dates:, supported_pairs:, rates_by_pair:, role:, sort_order:, navigation_context:, source_id: nil,
        selected_source: nil, fx_sources: [], selected_market: nil, sync_poll: false, available_markets: [], latest_upload: nil,
        sync_date_range: nil, upload_status_stream: nil, latest_ingestions: {}, rate_lineage: {})
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
        @sync_date_range = sync_date_range
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

      def sync_date_from
        sync_date_range&.date_from&.iso8601
      end

      def sync_date_to
        sync_date_range&.date_to&.iso8601
      end

      def sync_date_to_max
        sync_date_range&.max_date_to&.iso8601
      end

      def history_link_params(extra = {})
        navigation_context.merge(
          sort: sort_order,
          sync_source_id: selected_source_id,
          market: selected_market
        ).merge(extra).compact
      end

      def fiat_chart_series
        @fiat_chart_series ||= [
          {key: "ars_usd", label: "ARS/USD", color: "#38bdf8"},
          {key: "ars_eur", label: "ARS/EUR", color: "#a78bfa"}
        ].select { |series| chart_has_values?(points: fiat_chart_points, key: series[:key]) }
      end

      def fiat_chart_points
        @fiat_chart_points ||= dates.map do |date|
          {
            :label => I18n.l(date),
            :timestamp => date.iso8601,
            "ars_usd" => inverse_pair_value(base_currency: "USD", quote_currency: "ARS", date: date),
            "ars_eur" => inverse_pair_value(base_currency: "EUR", quote_currency: "ARS", date: date)
          }
        end
      end

      def fiat_chart?
        chart_renderable?(series: fiat_chart_series, points: fiat_chart_points)
      end

      def crypto_chart_series
        @crypto_chart_series ||= [
          {key: "btc_usd", label: "BTC/USD", color: "#22c55e"},
          {key: "eth_usd", label: "ETH/USD", color: "#f59e0b"}
        ].select { |series| chart_has_values?(points: crypto_chart_points, key: series[:key]) }
      end

      def crypto_chart_points
        @crypto_chart_points ||= dates.map do |date|
          {
            :label => I18n.l(date),
            :timestamp => date.iso8601,
            "btc_usd" => rate_value(base_currency: "BTC", quote_currency: "USD", date: date),
            "eth_usd" => rate_value(base_currency: "ETH", quote_currency: "USD", date: date)
          }
        end
      end

      def crypto_chart?
        chart_renderable?(series: crypto_chart_series, points: crypto_chart_points)
      end

      attr_reader :dates, :supported_pairs, :rates_by_pair, :role, :sort_order, :navigation_context, :source_id,
        :selected_source, :fx_sources, :selected_market, :sync_poll, :available_markets, :latest_upload, :upload_status_stream,
        :latest_ingestions, :rate_lineage, :sync_date_range

      private

      def format_market_label(market)
        normalized = market.to_s.upcase.gsub(/[^A-Z]/, "")
        return market if normalized.length != 6

        "#{normalized[0, 3]}/#{normalized[3, 3]}"
      end

      def rate_value(base_currency:, quote_currency:, date:)
        pair = rates_by_pair.fetch("#{base_currency}/#{quote_currency}", {})
        pair[date]&.rate&.to_f
      end

      def inverse_pair_value(base_currency:, quote_currency:, date:)
        direct = rate_value(base_currency: base_currency, quote_currency: quote_currency, date: date)
        return nil if direct.blank? || direct <= 0

        1.0 / direct
      end

      def chart_has_values?(points:, key:)
        points.any? { |point| point[key].present? }
      end

      def chart_renderable?(series:, points:)
        return false if series.empty?

        points.any? do |point|
          series.any? { |item| point[item[:key]].present? }
        end
      end
    end
  end
end
