# frozen_string_literal: true

module Admin
  module DemoDataset
    class ProcessUpload
      def initialize(
        parser: Admin::DemoDataset::ExcelToInputParser,
        run_repository: Admin::DemoDataset::Repositories::ActiveRecord::RunRepository.new,
        upload_repository: Admin::DemoDataset::Repositories::ActiveRecord::UploadRepository.new,
        execute_run: ->(run, fee_enabled:) { ::Runs::Execute.new.call(run, fee_enabled: fee_enabled) },
        verify_input_hash: ->(run) { ::Runs::VerifyInputHash.new.call(run) },
        process_upload_rate_gaps: lambda { |input, run, upload, reporting_currency|
          Admin::Fx::UploadRateGapProcessor.call(
            input: input,
            run: run,
            upload: upload,
            reporting_currency: reporting_currency
          )
        }
      )
        @parser = parser
        @run_repository = run_repository
        @upload_repository = upload_repository
        @execute_run = execute_run
        @verify_input_hash = verify_input_hash
        @process_upload_rate_gaps = process_upload_rate_gaps
      end

      def call(file_path:, timeline_enabled:)
        result = @parser.call(file_path: file_path, timeline_enabled: timeline_enabled)

        return handle_invalid(result) unless result.valid?

        run = @run_repository.create_with_input!(input_json: result.input)
        fee_enabled = result.input.dig('feeModel', 'enabled')

        with_timeline_env(timeline_enabled) do
          @execute_run.call(run, fee_enabled: fee_enabled)
          @verify_input_hash.call(run)
        end

        upload = @upload_repository.create_valid!(run_id: run.id)
        @process_upload_rate_gaps.call(result.input, run, upload, ReportingSetting.current.reporting_currency)

        { valid: true, run: run, upload: upload, errors: [] }
      end

      private

      def handle_invalid(result)
        upload = @upload_repository.create_invalid!(validation_errors: result.errors)
        { valid: false, run: nil, upload: upload, errors: result.errors }
      end

      def with_timeline_env(enabled)
        previous = ENV.fetch('FCS_TIMELINE_ENABLED', nil)
        ENV['FCS_TIMELINE_ENABLED'] = enabled ? '1' : '0'
        yield
      ensure
        if previous.nil?
          ENV.delete('FCS_TIMELINE_ENABLED')
        else
          ENV['FCS_TIMELINE_ENABLED'] = previous
        end
      end
    end
  end
end
