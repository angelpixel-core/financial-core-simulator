# frozen_string_literal: true

module Admin
  module Fx
    class HistoryTableComponent < ViewComponent::Base
      def initialize(dates:, supported_pairs:, rates_by_pair:, role:, sort_order:, navigation_context:, source_id: nil,
        rate_lineage: {})
        @dates = dates
        @supported_pairs = supported_pairs
        @rates_by_pair = rates_by_pair
        @role = role
        @sort_order = sort_order
        @navigation_context = navigation_context
        @source_id = source_id
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

      attr_reader :dates, :supported_pairs, :rates_by_pair, :role, :sort_order, :navigation_context, :source_id,
        :rate_lineage
    end
  end
end
