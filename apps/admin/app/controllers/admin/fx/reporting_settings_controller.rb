# frozen_string_literal: true

class Admin::Fx::ReportingSettingsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!

  def update
    Admin::Fx::ReportingSettingsUpdater.call(
      reporting_currency: reporting_currency,
      updated_by_id: current_admin_account&.id,
      updated_by_role: admin_shell_role,
      updated_context: request_context
    )

    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
                  notice: t('admin.fx.flash.reporting_updated')
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
                  alert: e.record.errors.full_messages.to_sentence
  end

  private

  def reporting_currency
    params[:reporting_currency]
  end

  def request_context
    {
      source: 'admin_overview',
      ip: request.remote_ip
    }
  end
end
