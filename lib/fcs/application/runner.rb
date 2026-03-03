# frozen_string_literal: true

require 'securerandom'

module FCS
  module Application
    class Runner
      def initialize(
        parser: FCS::Ingestion::Parser.new,
        validator: FCS::Ingestion::Validator.new,
        sorter: FCS::Engine::TradeSorter.new,
        simulate: FCS::Application::Simulate.new,
        artifacts_writer: FCS::Application::ReportArtifactsWriter.new,
        cli: FCS::Reporting::CliSummary.new,
        logger: FCS.logger
      )
        @parser = parser
        @validator = validator
        @sorter = sorter
        @simulate = simulate
        @artifacts_writer = artifacts_writer
        @cli = cli
        @logger = logger
      end

      def run!(input_path:, output_dir:, fee_enabled:, explain: false, verbose: false)
        @logger.info("fcs.run.start input=#{input_path} output=#{output_dir}")

        input = @parser.parse_file(input_path)

        # CLI flag tiene precedencia (y además deja el input normalizado)
        input['feeModel'] ||= {}
        input['feeModel']['enabled'] = !!fee_enabled

        @validator.validate!(input)

        input = prepare_execution_input(input)

        canonical = FCS::Hashing::CanonicalJSON.dump(input)
        input_hash = FCS::Hashing::SHA256.hex(canonical)

        schema_version = input.fetch('schemaVersion')
        valuation_ts = input.dig('priceSnapshot', 'valuationTimestamp')

        run_id = SecureRandom.uuid

        result = @simulate.call(input, explain: explain)

        payload = FCS::Application::ReportPayloadBuilder.build(
          engine_version: FCS::VERSION,
          schema_version: schema_version,
          input_hash: input_hash,
          run_id: run_id,
          valuation_timestamp: valuation_ts,
          accounts: result.fetch('accounts'),
          global: result.fetch('global')
        )

        artifacts = @artifacts_writer.write_all!(
          output_dir: output_dir,
          payload: payload
        )

        json_path = artifacts.fetch(:json_path)

        @cli.print(payload) if verbose

        @logger.info("fcs.run.done run_id=#{run_id} output=#{json_path}")

        json_path
      end

      private

      def prepare_execution_input(input)
        return prepare_batch_input(input) unless timeline_mode_enabled?(input)

        input['trades'] = extract_timeline_trades(input)
        input
      end

      def prepare_batch_input(input)
        input.delete('timeline')
        input['trades'] = @sorter.sort(input.fetch('trades'))
        input
      end

      def timeline_mode_enabled?(input)
        ENV['FCS_TIMELINE_ENABLED'] == '1' && input['timeline'].is_a?(Hash) && input['timeline']['events'].is_a?(Array)
      end

      def extract_timeline_trades(input)
        input
          .fetch('timeline')
          .fetch('events')
          .sort_by { |event| event.fetch('timelineSeq') }
          .select { |event| event.fetch('eventType') == 'TRADE_APPLIED' }
          .map { |event| event.fetch('trade') }
      end
    end
  end
end
