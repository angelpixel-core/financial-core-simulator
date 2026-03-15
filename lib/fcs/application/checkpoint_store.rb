require "json"
require "fileutils"

module FCS
  module Application
    class CheckpointStore
      def initialize(output_dir:, checkpoint_every:, engine_version:, schema_version:)
        @output_dir = output_dir
        @checkpoint_every = checkpoint_every
        @engine_version = engine_version
        @schema_version = schema_version
      end

      def write_if_due!(event_count:, timeline_seq:, state:, input_hash:)
        return nil unless checkpoint_due?(event_count)

        checkpoint = build_checkpoint(
          timeline_seq: timeline_seq,
          state: state,
          input_hash: input_hash
        )

        persist_checkpoint!(checkpoint)
        checkpoint
      end

      def latest_checkpoint
        path = latest_checkpoint_path
        return nil if path.nil?

        checkpoint = JSON.parse(File.read(path))
        validate_checkpoint_compatibility!(checkpoint)
        checkpoint
      end

      private

      def checkpoint_due?(event_count)
        return false unless @checkpoint_every.is_a?(Integer)
        return false if @checkpoint_every <= 0

        (event_count % @checkpoint_every).zero?
      end

      def build_checkpoint(timeline_seq:, state:, input_hash:)
        {
          "timelineSeq" => timeline_seq,
          "state" => state,
          "metadata" => {
            "engineVersion" => @engine_version,
            "schemaVersion" => @schema_version,
            "inputHash" => input_hash,
            "stateHash" => state_hash_for(state)
          }
        }
      end

      def state_hash_for(state)
        canonical = FCS::Hashing::CanonicalJSON.dump(state)
        FCS::Hashing::SHA256.hex(canonical)
      end

      def persist_checkpoint!(checkpoint)
        FileUtils.mkdir_p(@output_dir)
        path = File.join(@output_dir, checkpoint_filename(checkpoint.fetch("timelineSeq")))
        File.write(path, JSON.pretty_generate(checkpoint))
      end

      def checkpoint_filename(timeline_seq)
        "checkpoint_#{timeline_seq}.json"
      end

      def latest_checkpoint_path
        paths = Dir.glob(File.join(@output_dir, "checkpoint_*.json"))
        return nil if paths.empty?

        paths.max_by do |path|
          File.basename(path).match(/checkpoint_(\d+)\.json/)[1].to_i
        end
      end

      def validate_checkpoint_compatibility!(checkpoint)
        metadata = checkpoint["metadata"]
        return if metadata.nil?

        unless metadata["engineVersion"] == @engine_version
          raise FCS::Error.new(
            FCS::Errors::ERR_VALIDATION,
            "Incompatible checkpoint engineVersion",
            details: {
              expectedEngineVersion: @engine_version,
              checkpointEngineVersion: metadata["engineVersion"]
            }
          )
        end

        return if metadata["schemaVersion"] == @schema_version

        raise FCS::Error.new(
          FCS::Errors::ERR_VALIDATION,
          "Incompatible checkpoint schemaVersion",
          details: {
            expectedSchemaVersion: @schema_version,
            checkpointSchemaVersion: metadata["schemaVersion"]
          }
        )
      end
    end
  end
end
