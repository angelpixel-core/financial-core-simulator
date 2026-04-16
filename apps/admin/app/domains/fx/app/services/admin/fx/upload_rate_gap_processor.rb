# frozen_string_literal: true

module Admin
  module Fx
    class UploadRateGapProcessor
      def initialize(
        rate_repository: Admin::Fx::Rates::Repository.new,
        gap_repository: Admin::Fx::Gaps::Repository.new
      )
        @rate_repository = rate_repository
        @gap_repository = gap_repository
      end

      def self.call(input:, run:, reporting_currency:, upload: nil)
        new.call(input: input, run: run, upload: upload, reporting_currency: reporting_currency)
      end

      def call(input:, run:, reporting_currency:, upload: nil)
        return if input.blank? || reporting_currency.blank?

        base_currency = Admin::Fx::RateResolver::BASE_CURRENCY
        quote_currency = reporting_currency.to_s.upcase
        return if base_currency == quote_currency

        dates = operational_dates_from(input)
        return if dates.empty?

        dates.each do |operational_date|
          rate = @rate_repository.find_by(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency
          )

          next if rate&.rate.present?

          gap = @gap_repository.open_for(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency
          )

          placeholder = rate
          if placeholder.nil?
            placeholder = @rate_repository.create_placeholder!(
              operational_date: operational_date,
              base_currency: base_currency,
              quote_currency: quote_currency,
              source_run_id: run&.id,
              source_upload_id: upload&.id,
              created_context: { source: 'upload' }
            )
          end

          next if gap.present?

          @gap_repository.create_open!(
            operational_date: operational_date,
            base_currency: base_currency,
            quote_currency: quote_currency,
            placeholder_rate_id: placeholder.id,
            source_run_id: run&.id,
            source_upload_id: upload&.id,
            created_context: { source: 'upload' }
          )
        end
      end

      private

      def operational_dates_from(input)
        dates = []
        trades = Array(input['trades'] || input[:trades])
        trades.each do |trade|
          next unless trade.is_a?(Hash)

          timestamp = trade['timestamp'] || trade[:timestamp]
          date = operational_date_for(timestamp)
          dates << date if date
        end

        timeline = input['timeline'] || input[:timeline]
        events = timeline.is_a?(Hash) ? Array(timeline['events'] || timeline[:events]) : []
        events.each do |event|
          next unless event.is_a?(Hash)

          timestamp = event['timestamp'] || event[:timestamp]
          date = operational_date_for(timestamp)
          dates << date if date
        end

        dates.compact.uniq
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
