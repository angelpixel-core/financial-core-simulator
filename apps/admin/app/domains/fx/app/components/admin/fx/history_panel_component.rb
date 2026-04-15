# frozen_string_literal: true

module Admin
  module Fx
    class HistoryPanelComponent < ViewComponent::Base
      def initialize(base_currency:, quote_currency:, role:)
        @base_currency = base_currency
        @quote_currency = quote_currency
        @role = role
      end

      def entries
        rates = FxDailyRate.where(base_currency: base_currency, quote_currency: quote_currency)
          .order(operational_date: :desc)
          .limit(10)
          .to_a
        preload_gap_associations!(rates)
        rates
      end

      def can_edit?
        %w[operator admin].include?(role)
      end

      def gap_status(rate)
        return nil unless rate.placeholder?

        gap = rate.placeholder_gap || FxRateGap.open_for(
          operational_date: rate.operational_date,
          base_currency: rate.base_currency,
          quote_currency: rate.quote_currency
        )
        gap&.status
      end

      def display_rate(rate)
        return t("admin.fx.history.placeholder_value") if rate.rate.nil?

        rate.rate.to_s
      end

      def editable_rate?(rate)
        can_edit? && (rate.manual? || rate.placeholder?)
      end

      def deletable_rate?(rate)
        editable_rate?(rate) && !rate.linked_to_system?
      end

      attr_reader :base_currency, :quote_currency, :role

      private

      def preload_gap_associations!(records)
        placeholder_rates = records.select(&:placeholder?)
        if placeholder_rates.any?
          ActiveRecord::Associations::Preloader.new(
            records: placeholder_rates,
            associations: :placeholder_gap
          ).call
        end

        return unless can_edit?

        editable_rates = records.select { |rate| rate.manual? || rate.placeholder? }
        return if editable_rates.empty?

        ActiveRecord::Associations::Preloader.new(
          records: editable_rates,
          associations: :resolved_gap
        ).call
      end
    end
  end
end
