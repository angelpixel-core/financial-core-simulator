# frozen_string_literal: true

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

        run_id = deterministic_run_id(input_hash)

        checkpoint_store = build_checkpoint_store(output_dir: output_dir, schema_version: schema_version)
        checkpoint = checkpoint_store&.latest_checkpoint
        input['checkpoint'] ||= checkpoint unless checkpoint.nil?

        result = @simulate.call(
          input,
          explain: explain,
          checkpoint_store: checkpoint_store,
          input_hash: input_hash
        )

        payload = FCS::Application::ReportPayloadBuilder.build(
          engine_version: FCS::VERSION,
          schema_version: schema_version,
          input_hash: input_hash,
          run_id: run_id,
          valuation_timestamp: valuation_ts,
          accounts: result.fetch('accounts'),
          global: result.fetch('global'),
          replay: build_replay_metadata(input: input, checkpoint: checkpoint)
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

      def build_checkpoint_store(output_dir:, schema_version:)
        return nil unless timeline_feature_enabled?

        checkpoint_every = ENV.fetch('FCS_CHECKPOINT_EVERY', '100').to_i
        return nil if checkpoint_every <= 0

        FCS::Application::CheckpointStore.new(
          output_dir: output_dir,
          checkpoint_every: checkpoint_every,
          engine_version: FCS::VERSION,
          schema_version: schema_version
        )
      end

      def timeline_feature_enabled?
        ENV['FCS_TIMELINE_ENABLED'] == '1'
      end

      def build_replay_metadata(input:, checkpoint:)
        timeline = input['timeline']
        return nil unless timeline.is_a?(Hash) && timeline['events'].is_a?(Array)

        metadata = { 'mode' => 'timeline' }
        if checkpoint.is_a?(Hash) && checkpoint.key?('timelineSeq')
          metadata['checkpointTimelineSeq'] =
            checkpoint['timelineSeq']
        end
        metadata
      end

      def deterministic_run_id(input_hash)
        hex = FCS::Hashing::SHA256.hex("run:#{input_hash}")
        versioned = "5#{hex[13, 3]}"
        variant = ((hex[16].hex & 0x3) | 0x8).to_s(16)
        varianted = "#{variant}#{hex[17, 3]}"

        "#{hex[0, 8]}-#{hex[8, 4]}-#{versioned}-#{varianted}-#{hex[20, 12]}"
      end
    end
  end
end
