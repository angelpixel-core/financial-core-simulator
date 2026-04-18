# frozen_string_literal: true

module Admin
  module Fx
    class HistoryTableComponent < ViewComponent::Base
      def initialize(dates:, supported_pairs:, rates_by_pair:, role:, sort_order:, navigation_context:, source_id: nil,
                     selected_source: nil, fx_sources: [], selected_market: nil, available_markets: [], latest_upload: nil,
                     upload_status_stream: nil, rate_lineage: {})
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
        @available_markets = available_markets
        @latest_upload = latest_upload
        @upload_status_stream = upload_status_stream
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
        return t('admin.fx.history.placeholder_value') if rate.nil? || rate.rate.nil?

        helpers.truncate_fiat(rate.rate, rate.quote_currency)
      end

      def sort_label
        t("admin.fx.history.table.sort_#{sort_order}")
      end

      def toggle_sort_order
        sort_order == 'asc' ? 'desc' : 'asc'
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

      def market_select_options
        available_markets.map { |market| [market, market] }
      end

      def source_select_options
        [[I18n.t('admin.fx.history.filter.all_sources'), '']] + fx_sources.map { |source| [source.name, source.id] }
      end

      attr_reader :dates, :supported_pairs, :rates_by_pair, :role, :sort_order, :navigation_context, :source_id,
                  :selected_source, :fx_sources, :selected_market, :available_markets, :latest_upload, :upload_status_stream,
                  :rate_lineage
    end
  end
end
