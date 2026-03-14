module Admin
  module Runs
    class ValidationIssuesPanelComponent < ViewComponent::Base
      def initialize(title:, state:, diagnostic:, issues: [])
        @title = title
        @state = state.to_sym
        @diagnostic = diagnostic
        @issues = Array(issues)
      end

      def state_class
        case @state
        when :success
          "validation-issues-panel--success"
        when :warning
          "validation-issues-panel--warning"
        when :error
          "validation-issues-panel--error"
        when :loading
          "validation-issues-panel--loading"
        else
          "validation-issues-panel--info"
        end
      end

      def state_label
        case @state
        when :success
          "OK"
        when :warning
          "Warning"
        when :error
          "Error"
        when :loading
          "Loading"
        else
          "Info"
        end
      end

      def state_icon
        case @state
        when :success
          "OK"
        when :warning
          "!"
        when :error
          "X"
        when :loading
          "..."
        else
          "i"
        end
      end

      def issues?
        @issues.any?
      end

      def issue_severity_label(issue)
        case issue[:severity].to_s
        when "warning"
          "Warning"
        when "info"
          "Info"
        else
          "Error"
        end
      end

      def issue_severity_class(issue)
        case issue[:severity].to_s
        when "warning"
          "validation-issues-panel__severity--warning"
        when "info"
          "validation-issues-panel__severity--info"
        else
          "validation-issues-panel__severity--error"
        end
      end
    end
  end
end
