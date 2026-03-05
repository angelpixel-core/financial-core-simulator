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

      expanded_path = Pathname.new(raw_path).expand_path
      return nil unless expanded_path.file?

      resolved_storage_root = resolve_storage_root
      resolved_artifact_path = expanded_path.realpath
      allowed_prefix = "#{resolved_storage_root}#{File::SEPARATOR}"

      return nil unless resolved_artifact_path.to_s.start_with?(allowed_prefix)

      resolved_artifact_path.to_s
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end

    private

    def resolve_storage_root
      storage_root = Pathname.new(@storage_root)
      return storage_root.realpath if storage_root.exist?

      storage_root
    end
  end
end
