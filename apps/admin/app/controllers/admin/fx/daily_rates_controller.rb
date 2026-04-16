# frozen_string_literal: true

class Admin::Fx::DailyRatesController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!
  before_action :authorize_fx_rate_management_policy!

  def create
    Admin::Fx::Api.upsert_rate(
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
    Admin::Fx::Api.carry_forward_rate(
      operational_date: operational_date,
      base_currency: base_currency,
      quote_currency: quote_currency,
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
    Admin::Fx::Api.update_rate(
      rate_id: params[:id],
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

  def destroy
    Admin::Fx::Api.delete_rate(rate_id: params[:id])
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      notice: t("admin.fx.flash.rate_deleted")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_overview_path(locale: I18n.locale),
      alert: e.record.errors.full_messages.to_sentence
  end

  def current
    Admin::Fx::Api.upsert_rate(
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
    Admin::Fx::Api.operational_date(value: value)
  end

  def base_currency
    params[:base_currency].presence || fx_daily_rate_params[:base_currency].presence || Admin::Fx::Api.base_currency
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
