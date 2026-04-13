# frozen_string_literal: true

module Admin
  module Fx
    class HistorySnapshot
      def self.call(sort_order: "desc", supported_pairs: Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS,
        source_id: nil)
        new(sort_order: sort_order, supported_pairs: supported_pairs, source_id: source_id).call
      end

      def initialize(sort_order:, supported_pairs:, source_id: nil)
        @sort_order = (sort_order.to_s == "asc") ? "asc" : "desc"
        @supported_pairs = supported_pairs
        @source_id = source_id
      end

      def call
        rates_by_pair = supported_pairs.to_h do |base_currency, quote_currency|
          ["#{base_currency}/#{quote_currency}", {}]
        end

        rates = FxDailyRate.where(*supported_pair_conditions)
        rates = rates.where(source_id: source_id) if source_id.present?
        rates = rates.includes(:rate_source).order(operational_date: sort_order).to_a

        preload_placeholder_gaps!(rates)

        dates = rates.map(&:operational_date).uniq
        dates.sort!
        dates.reverse! if sort_order == "desc"

        rates.each do |rate|
          rates_by_pair["#{rate.base_currency}/#{rate.quote_currency}"][rate.operational_date] = rate
        end

        {
          supported_pairs: supported_pairs,
          sort_order: sort_order,
          rates_by_pair: rates_by_pair,
          dates: dates,
          empty_history: dates.blank?,
          rates: rates
        }
      end

      private

      attr_reader :sort_order, :supported_pairs, :source_id

      def supported_pair_conditions
        statement = supported_pairs.map { "(base_currency = ? AND quote_currency = ?)" }.join(" OR ")
        [statement, *supported_pairs.flatten]
      end

      def preload_placeholder_gaps!(rates)
        placeholder_rates = rates.select(&:placeholder?)
        return if placeholder_rates.empty?

        ActiveRecord::Associations::Preloader.new(
          records: placeholder_rates,
          associations: :placeholder_gap
        ).call
      end
    end
  end
end
