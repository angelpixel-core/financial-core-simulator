# frozen_string_literal: true

module FCS
  module Ports
    class ArtifactStore
      def build_output_dir(run_id:)
        raise NotImplementedError, "#{self.class} must implement #build_output_dir"
      end

      def artifact_paths(output_dir:, execution_result:)
        raise NotImplementedError, "#{self.class} must implement #artifact_paths"
      end
    end
  end
end
