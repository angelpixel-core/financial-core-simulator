# frozen_string_literal: true

class Admin::Fx::DailyRatesController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!
  before_action :authorize_fx_rate_management_policy!

  def create
    Admin::Fx::RateUpserter.call(
      operational_date: operational_date,
      base_currency: base_currency,
      quote_currency: quote_currency,
      rate: rate_value,
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: request_context
    )

    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_saved")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      alert: e.record.errors.full_messages.to_sentence
  end

  def carry_forward
    Admin::Fx::CarryForwardRate.call(
      operational_date: operational_date,
      base_currency: base_currency,
      quote_currency: quote_currency,
      source: "carry_forward",
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: request_context
    )

    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_carried_forward")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      alert: e.record.errors.full_messages.to_sentence
  end

  def update
    rate = FxDailyRate.find(params[:id])

    unless rate.manual? || rate.placeholder?
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.fx.flash.rate_edit_blocked")
      return
    end

    context = rate.created_context || {}
    rate.assign_attributes(
      rate: rate_value,
      source: "manual",
      source_rate_id: nil,
      source_run_id: nil,
      source_upload_id: nil,
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: context.merge(request_context)
    )

    rate.save!
    Admin::Fx::GapResolver.call(rate: rate)

    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_saved")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    rate = FxDailyRate.find(params[:id])

    if !rate.manual? || rate.linked_to_system?
      redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
        alert: t("admin.fx.flash.rate_delete_blocked")
      return
    end

    rate.destroy!
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_deleted")
  end

  def current
    Admin::Fx::RateUpserter.call(
      operational_date: operational_date,
      base_currency: base_currency,
      quote_currency: quote_currency,
      rate: rate_value,
      created_by_id: current_admin_account&.id,
      created_by_role: admin_shell_role,
      created_context: request_context
    )

    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_saved")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      alert: e.record.errors.full_messages.to_sentence
  end

  private

  def authorize_fx_rate_management_policy!
    authorize_policy!(FxRatePolicy, :manage_rates?, record: :fx_rate)
  end

  def operational_date
    value = params[:operational_date].presence || fx_daily_rate_params[:operational_date].presence
    return Admin::Fx::OperationalDate.call if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    Admin::Fx::OperationalDate.call
  end

  def base_currency
    params[:base_currency].presence || fx_daily_rate_params[:base_currency].presence || Admin::Fx::RateResolver::BASE_CURRENCY
  end

  def quote_currency
    params[:quote_currency].presence || fx_daily_rate_params[:quote_currency].presence || ReportingSetting.current.reporting_currency
  end

  def rate_value
    params[:rate] || fx_daily_rate_params[:rate]
  end

  def fx_daily_rate_params
    value = params[:fx_daily_rate]
    value.is_a?(ActionController::Parameters) ? value : {}
  end

  def request_context
    {
      source: "admin_overview",
      ip: request.remote_ip
    }
  end
end
