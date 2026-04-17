# frozen_string_literal: true

require 'json'
require 'prawn'

module Admin
  module Dashboard
    class FinancialOverviewExporter
      CARD_TYPES = {
        'trade-activity-dashboard' => {
          metric_key: :trade_activity,
          title: 'Trade Activity Dashboard'
        },
        'trade-volume-dashboard' => {
          metric_key: :trade_volume,
          title: 'Trade Volume Dashboard'
        },
        'profit-and-loss-dashboard' => {
          metric_key: :pnl_daily,
          title: 'Profit and Loss Dashboard'
        }
      }.freeze

      class UnsupportedCardTypeError < StandardError; end

      def initialize(run:, card_type:, account_id: nil, market_id: nil, run_filenames: [], generated_at: Time.current)
        @run = run
        @card_type = card_type.to_s
        @account_id = account_id
        @market_id = market_id
        @run_filenames = Array(run_filenames).filter_map { |value| value.to_s.strip.presence }.uniq
        @generated_at = generated_at
      end

      def export_json
        definition = card_definition

        {
          dashboard: {
            id: @card_type,
            title: definition.fetch(:title)
          },
          run: {
            id: @run.id,
            status: @run.status,
            reliable: @run.reliable
          },
          filters: {
            account_id: @account_id,
            market_id: @market_id,
            run_filenames: @run_filenames
          }.compact,
          generated_at: @generated_at.utc.iso8601,
          data: card_data(definition)
        }
      end

      def export_pdf
        definition = card_definition
        data_rows = Array(card_data(definition))

        Prawn::Document.new(page_size: 'A4', margin: 36) do |pdf|
          pdf.text definition.fetch(:title), size: 18, style: :bold
          pdf.move_down 8
          pdf.text "Run ##{@run.id} - #{@run.status.upcase}"
          pdf.text "Reliable: #{@run.reliable ? 'YES' : 'NO'}"
          pdf.text "Generated at: #{@generated_at.utc.iso8601}"
          if @account_id.present? || @market_id.present?
            filters = []
            filters << "account=#{@account_id}" if @account_id.present?
            filters << "market=#{@market_id}" if @market_id.present?
            pdf.text "Filters: #{filters.join(', ')}"
          end
          if @run_filenames.any?
            pdf.text "Runs: #{@run_filenames.join(', ')}"
          else
            pdf.text 'Runs: all processed files'
          end

          pdf.move_down 14
          pdf.text 'Card Visual Summary', size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 8
          pdf.text("Points: #{data_rows.size}")
          if data_rows.first.is_a?(Hash)
            summary_line = data_rows.first.slice('timestamp', 'trade_count', 'volume', 'total_pnl').compact
            pdf.text("Latest sample: #{summary_line.map { |k, v| "#{k}=#{v}" }.join(' | ')}") unless summary_line.empty?
          end

          pdf.move_down 14
          pdf.text 'Tabular Report', size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 8

          if data_rows.empty?
            pdf.text 'No rows available for selected filters.'
          else
            keys = data_rows.flat_map(&:keys).uniq
            pdf.text keys.join(' | '), style: :bold, size: 9
            pdf.move_down 4
            data_rows.each do |row|
              values = keys.map { |key| row[key].to_s }
              pdf.text values.join(' | '), size: 9
            end
          end
        end.render
      end

      def filename_for(format)
        ext = format.to_s.downcase == 'pdf' ? 'pdf' : 'json'
        "#{@card_type}.#{ext}"
      end

      private

      def card_definition
        CARD_TYPES.fetch(@card_type)
      rescue KeyError
        raise UnsupportedCardTypeError, "Unsupported dashboard card: #{@card_type}"
      end

      def card_data(definition)
        metrics = Admin::Dashboard::FinancialOverviewMetrics.new(
          run: @run,
          account_id: @account_id,
          market_id: @market_id,
          run_filenames: @run_filenames
        ).call

        Array(metrics.fetch(definition.fetch(:metric_key), []))
      end
    end
  end
end
