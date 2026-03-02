module Artifacts
  class PathResolver
    def initialize(run:, attribute:, storage_root: Rails.root.join("storage", "runs"))
      @run = run
      @attribute = attribute
      @storage_root = File.expand_path(storage_root)
    end

    def call
      raw_path = @run.public_send(@attribute)
      return nil if raw_path.blank?

      expanded_path = File.expand_path(raw_path)
      allowed_prefix = "#{@storage_root}#{File::SEPARATOR}"

      return nil unless expanded_path.start_with?(allowed_prefix)
      return nil unless File.file?(expanded_path)

      expanded_path
    end
  end
end
