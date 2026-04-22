# frozen_string_literal: true

module Admin
  module UploadLimits
    module_function

    def max_upload_file_size_mb
      env_integer("MAX_UPLOAD_FILE_SIZE_MB", 10)
    end

    def max_upload_file_size_bytes
      max_upload_file_size_mb.megabytes
    end

    def max_upload_rows
      env_integer("MAX_UPLOAD_ROWS", 50_000)
    end

    def max_preview_rows
      env_integer("MAX_PREVIEW_ROWS", 200)
    end

    def max_preview_errors
      env_integer("MAX_PREVIEW_ERRORS", 100)
    end

    def batch_size
      env_integer("UPLOAD_BATCH_SIZE", 1_000)
    end

    def file_size_bytes(file_path: nil, file: nil)
      return File.size(file_path) if file_path.present?

      return File.size(file.tempfile.path) if file.respond_to?(:tempfile) && file.tempfile&.path.present?
      return file.size if file.respond_to?(:size)

      0
    rescue Errno::ENOENT
      0
    end

    def exceeds_file_size?(file_path: nil, file: nil)
      file_size_bytes(file_path: file_path, file: file) > max_upload_file_size_bytes
    end

    def env_integer(key, default)
      value = ENV[key].to_i
      value.positive? ? value : default
    end
  end
end
