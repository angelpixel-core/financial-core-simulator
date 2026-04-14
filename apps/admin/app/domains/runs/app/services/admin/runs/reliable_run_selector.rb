module Admin
  module Runs
    class ReliableRunSelector
      Result = Struct.new(:reliable_run, :candidate_run, :state, :diagnostic, keyword_init: true)

      def call
        latest = latest_successful_run || latest_run
        return degraded_result(latest) if non_reliable_candidate?(latest)

        reliable = latest_verified_run
        return reliable_result(reliable) if reliable.present?

        degraded_result
      end

      private

      def latest_verified_run
        Run.succeeded.where(verification_status: Run.verification_statuses.fetch("verified")).order(id: :desc).first
      end

      def latest_successful_run
        Run.succeeded.order(id: :desc).first
      end

      def latest_run
        Run.order(id: :desc).first
      end

      def reliable_result(run)
        Result.new(
          reliable_run: run,
          candidate_run: run,
          state: :reliable,
          diagnostic: {
            what_happened: I18n.t("admin.runs.reliable_run_selector.reliable.what_happened"),
            impact: I18n.t("admin.runs.reliable_run_selector.reliable.impact"),
            next_action: I18n.t("admin.runs.reliable_run_selector.reliable.next_action")
          }
        )
      end

      def degraded_result(candidate = nil)
        candidate ||= latest_successful_run || latest_run

        Result.new(
          reliable_run: nil,
          candidate_run: candidate,
          state: :degraded,
          diagnostic: degraded_diagnostic(candidate)
        )
      end

      def degraded_diagnostic(candidate)
        return no_run_diagnostic if candidate.nil?
        return non_reliable_diagnostic(candidate) if non_reliable_candidate?(candidate)

        if candidate.verification_status == "verified"
          default_degraded_diagnostic
        else
          unverified_diagnostic(candidate)
        end
      end

      def non_reliable_candidate?(candidate)
        return false if candidate.nil?

        candidate.status == "succeeded" && candidate.reliable == false
      end

      def non_reliable_diagnostic(candidate)
        {
          what_happened: I18n.t("admin.runs.reliable_run_selector.non_reliable.what_happened"),
          impact: I18n.t("admin.runs.reliable_run_selector.non_reliable.impact"),
          next_action: I18n.t("admin.runs.reliable_run_selector.non_reliable.next_action", run_id: candidate.id)
        }
      end

      def no_run_diagnostic
        {
          what_happened: I18n.t("admin.runs.reliable_run_selector.no_run.what_happened"),
          impact: I18n.t("admin.runs.reliable_run_selector.no_run.impact"),
          next_action: I18n.t("admin.runs.reliable_run_selector.no_run.next_action")
        }
      end

      def unverified_diagnostic(candidate)
        status_label = candidate.status.to_s.tr("_", " ")
        verification_label = candidate.verification_status.to_s.tr("_", " ")

        {
          what_happened: I18n.t("admin.runs.reliable_run_selector.unverified.what_happened"),
          impact: I18n.t("admin.runs.reliable_run_selector.unverified.impact"),
          next_action: I18n.t(
            "admin.runs.reliable_run_selector.unverified.next_action",
            run_id: candidate.id,
            status: status_label,
            verification: verification_label
          )
        }
      end

      def default_degraded_diagnostic
        {
          what_happened: I18n.t("admin.runs.reliable_run_selector.degraded.what_happened"),
          impact: I18n.t("admin.runs.reliable_run_selector.degraded.impact"),
          next_action: I18n.t("admin.runs.reliable_run_selector.degraded.next_action")
        }
      end
    end
  end
end
