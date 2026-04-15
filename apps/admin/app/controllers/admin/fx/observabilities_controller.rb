# frozen_string_literal: true

class Admin::Fx::ObservabilitiesController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_viewer!
  before_action :authorize_fx_observability_policy!
  before_action :load_navigation_context

  def show
    @fx_sources = FxRateSource.order(:name)
    @selected_source = resolve_source(params[:source_id])
    @days = normalize_days(params[:days])

    if request.format.json? && params[:source_id].present? && @selected_source.nil?
      return render json: {error: "invalid_source_id"}, status: :unprocessable_content
    end

    @snapshot = Admin::Fx::ObservabilitySnapshot.call(source_id: @selected_source&.id, days: @days)

    respond_to do |format|
      format.html
      format.json { render json: observability_json }
    end
  rescue => e
    raise unless request.format.json?

    render json: {error: "internal_error", message: e.message}, status: :internal_server_error
  end

  private

  def authorize_fx_observability_policy!
    authorize_policy!(FxRatePolicy, :observability?, record: :fx_rate)
  end

  def resolve_source(source_id)
    return nil if source_id.blank?

    FxRateSource.find_by(id: source_id)
  end

  def normalize_days(value)
    number = value.to_i
    return number if number.positive?

    Admin::Fx::ObservabilitySnapshot::DEFAULT_DAYS
  end

  def observability_json
    @snapshot.merge(
      source_id: @selected_source&.id,
      source_name: @selected_source&.name
    )
  end

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
