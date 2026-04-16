# frozen_string_literal: true

module FCS
  module Application
    # Coordinates parsing, validation, simulation, and artifact generation.
    #
    # Public entrypoint for CLI-style runs. This object is responsible for
    # normalizing inputs, enforcing determinism, and producing artifacts.
    #
    # @example Run with input file
    #   runner = FCS::Application::Runner.new
    #   runner.run!(
    #     input_path: "data/input.json",
    #     output_dir: "tmp/fcs",
    #     fee_enabled: true,
    #     verbose: true
    #   )
    class Runner
      # @param parser [FCS::Ingestion::Parser]
      # @param validator [FCS::Ingestion::Validator]
      # @param sorter [FCS::Engine::TradeSorter]
      # @param simulate [FCS::Application::Simulate]
      # @param artifacts_writer [FCS::Application::ReportArtifactsWriter]
      # @param cli [FCS::Reporting::CliSummary]
      # @param logger [Logger, FCS::Logging::SimpleLogger]
      def initialize(
        parser: FCS::Ingestion::Parser.new,
        validator: FCS::Ingestion::Validator.new,
        sorter: FCS::Engine::TradeSorter.new,
        simulate: FCS::Application::Simulate.new,
        account_market_contract_validator: FCS::Reporting::AccountMarketContractValidator.new,
        result_metadata_contract_validator: FCS::Reporting::ResultMetadataContractValidator.new,
        cli: FCS::Reporting::CliSummary.new,
        logger: FCS.logger
      )
        @parser = parser
        @validator = validator
        @sorter = sorter
        @simulate = simulate
        @account_market_contract_validator = account_market_contract_validator
        @result_metadata_contract_validator = result_metadata_contract_validator
        @cli = cli
        @logger = logger
      end

      # Runs a simulation from an input file and writes artifacts to disk.
      #
      # @param input_path [String] JSON input path
      # @param output_dir [String] output directory for artifacts
      # @param fee_enabled [Boolean, nil] override for feeModel.enabled
      # @param explain [Boolean] include explain payload in market output
      # @param verbose [Boolean] print CLI summary
      # @return [Hash] execution metadata
      # @example
      #   result = runner.run!(
      #     input_path: "data/input.json",
      #     output_dir: "tmp/fcs",
      #     fee_enabled: false
      #   )
      def run!(input_path:, output_dir:, fee_enabled:, explain: false, verbose: false)
        raw_input = @parser.parse_file(input_path)

        run_from_input!(
          input: raw_input,
          output_dir: output_dir,
          fee_enabled: fee_enabled,
          explain: explain,
          verbose: verbose,
          input_source: input_path
        )
      end

      # Runs a simulation from a Ruby Hash input and writes artifacts.
      #
      # @param input [Hash] parsed input payload
      # @param output_dir [String] output directory for artifacts
      # @param fee_enabled [Boolean, nil] override for feeModel.enabled
      # @param explain [Boolean] include explain payload in market output
      # @param verbose [Boolean] print CLI summary
      # @param input_source [String] label used for logging
      # @return [Hash] execution metadata
      # @example
      #   result = runner.run_from_input!(
      #     input: payload,
      #     output_dir: "tmp/fcs",
      #     fee_enabled: true
      #   )
      #   result[:run_id]
      def run_from_input!(input:, output_dir:, fee_enabled:, explain: false, verbose: false, input_source: 'input')
        @logger.info("fcs.run.start input=#{input_source} output=#{output_dir}")

        raw_input = deep_copy(input)

        normalized_input = deep_copy(raw_input)
        normalized_input['feeModel'] ||= {}
        normalized_input['feeModel']['enabled'] = fee_enabled unless fee_enabled.nil?
        validation_result = @validator.validate_with_errors!(normalized_input)
        annotated_input = validation_result.fetch(:input)
        validation_errors = validation_result.fetch(:validation_errors)
        reliable = validation_result.fetch(:reliable)

        hash_input = prepare_execution_input(deep_copy(annotated_input))
        normalize_collections_for_determinism!(hash_input)
        canonical = FCS::Hashing::CanonicalJSON.dump(hash_input)
        input_hash = FCS::Hashing::SHA256.hex(canonical)

        execution_input = deep_copy(annotated_input)
        normalize_collections_for_determinism!(execution_input)
        execution_input = filter_valid_trades_for_execution(execution_input)
        execution_input = prepare_execution_input(execution_input)

        schema_version = execution_input.fetch('schemaVersion')
        valuation_ts = execution_input.dig('priceSnapshot', 'valuationTimestamp')

        run_id = deterministic_run_id(input_hash)

        checkpoint_store = build_checkpoint_store(output_dir: output_dir, schema_version: schema_version)
        checkpoint = checkpoint_store&.latest_checkpoint
        execution_input['checkpoint'] ||= checkpoint unless checkpoint.nil?

        result = @simulate.call(
          execution_input,
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
          replay: build_replay_metadata(input: execution_input, checkpoint: checkpoint),
          timeline: result['timeline']
        )

        @result_metadata_contract_validator.validate!(payload: payload)
        @account_market_contract_validator.validate!(accounts: payload.fetch('accounts'))

        @cli.print(payload, artifacts: {}, status: 'success') if verbose

        @logger.info("fcs.run.done run_id=#{run_id} output=database")

        FCS::Contracts::RunExecutionResult.from_hash!(
          input_hash: input_hash,
          run_id: run_id,
          schema_version: schema_version,
          valuation_timestamp: valuation_ts,
          payload: payload,
          artifacts: {},
          validation_errors: validation_errors,
          reliable: reliable,
          annotated_input: annotated_input
        )
      end

      private

      def prepare_execution_input(input)
        return prepare_batch_input(input) unless timeline_present?(input)

        if timeline_feature_enabled?
          prepare_timeline_input(input)
        else
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            'timeline input requires FCS_TIMELINE_ENABLED=1',
            details: { field: 'timeline' }
          )
        end
      end

      def prepare_batch_input(input)
        input.delete('timeline')
        input['trades'] = @sorter.sort(input.fetch('trades'))
        input
      end

      def prepare_timeline_input(input)
        events = input.fetch('timeline').fetch('events').sort_by { |event| event.fetch('timelineSeq') }
        input['timeline']['events'] = events
        input['trades'] = events.select { |event| event.fetch('eventType') == 'TRADE_APPLIED' }
                                .map { |event| event.fetch('trade') }
        input
      end

      def filter_valid_trades_for_execution(input)
        return input unless input.is_a?(Hash)

        trades = input['trades']
        input['trades'] = trades.select { |trade| valid_trade?(trade) } if trades.is_a?(Array)

        timeline = input['timeline']
        if timeline.is_a?(Hash)
          events = Array(timeline['events'])
          timeline['events'] = events.select do |event|
            next true unless event.is_a?(Hash)
            next true unless event.fetch('eventType', nil) == 'TRADE_APPLIED'

            valid_trade?(event['trade'])
          end
        end

        input
      end

      def valid_trade?(trade)
        return false unless trade.is_a?(Hash)

        valid = trade['valid']
        valid.nil? || valid == true
      end

      def normalize_collections_for_determinism!(input)
        input['accounts'] = sort_collection(input['accounts']) { |item| item.fetch('accountId') }
        input['markets'] = sort_collection(input['markets']) { |item| item.fetch('marketId') }

        prices = input.dig('priceSnapshot', 'prices')
        return unless prices.is_a?(Array)

        input['priceSnapshot']['prices'] = sort_collection(prices) { |item| item.fetch('marketId') }
      end

      def sort_collection(collection, &)
        return collection unless collection.is_a?(Array)

        collection.sort_by(&)
      end

      def deep_copy(value)
        Marshal.load(Marshal.dump(value))
      end

      def timeline_present?(input)
        input['timeline'].is_a?(Hash) && input['timeline']['events'].is_a?(Array)
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
