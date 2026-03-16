# frozen_string_literal: true

module FCS
  module Application
    # Writes result artifacts and validates their consistency.
    class ReportArtifactsWriter
      def initialize(
        reporter: FCS::Reporting::JsonReport.new,
        positions_csv: FCS::Reporting::CsvPositions.new,
        pnl_csv: FCS::Reporting::CsvPnL.new,
        csv_reconciler: FCS::Reporting::CsvArtifactReconciler.new,
        account_market_contract_validator: FCS::Reporting::AccountMarketContractValidator.new,
        result_metadata_contract_validator: FCS::Reporting::ResultMetadataContractValidator.new
      )
        @reporter = reporter
        @positions_csv = positions_csv
        @pnl_csv = pnl_csv
        @csv_reconciler = csv_reconciler
        @account_market_contract_validator = account_market_contract_validator
        @result_metadata_contract_validator = result_metadata_contract_validator
      end

      def write_all!(output_dir:, payload:)
        @result_metadata_contract_validator.validate!(payload: payload)
        @account_market_contract_validator.validate!(accounts: payload.fetch("accounts"))

        json_path = @reporter.write!(output_dir: output_dir, payload: payload)
        positions_path = @positions_csv.write!(output_dir: output_dir, accounts: payload.fetch("accounts"))
        pnl_path = @pnl_csv.write!(output_dir: output_dir, accounts: payload.fetch("accounts"))

        @csv_reconciler.validate!(
          json_path: json_path,
          positions_path: positions_path,
          pnl_path: pnl_path
        )

        {
          json_path: json_path,
          positions_csv_path: positions_path,
          pnl_csv_path: pnl_path
        }
      end
    end
  end
end
