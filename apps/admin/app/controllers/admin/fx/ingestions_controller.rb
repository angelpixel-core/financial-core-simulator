# frozen_string_literal: true

class Admin::Fx::IngestionsController < ApplicationController
  include AdminUiAuthorizable

  before_action :authorize_admin_session_operator!
  before_action :load_navigation_context

  def sync
    source = FxRateSource.find(params[:source_id])
    correlation_id = SecureRandom.uuid
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "pending",
      correlation_id: correlation_id
    )

    Admin::Fx::FetchFxRatesJob.perform_later(
      source.id,
      correlation_id: correlation_id,
      ingestion_id: ingestion.id
    )

    @fx_sources = FxRateSource.order(:name)
    @latest_ingestions = latest_ingestions(@fx_sources)
    @recent_events = FxRateEvent.order(created_at: :desc).limit(10)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "fx-ingestion-status",
            partial: "admin/fx/history/ingestion_status",
            locals: {fx_sources: @fx_sources, latest_ingestions: @latest_ingestions}
          ),
          turbo_stream.replace(
            "fx-recent-events",
            partial: "admin/fx/history/recent_events",
            locals: {events: @recent_events}
          )
        ]
      end
      format.html do
        redirect_to admin_fx_history_index_path(@navigation_context),
          notice: t("admin.fx.history.sync.started")
      end
    end
  end

  private

  def latest_ingestions(sources)
    FxRateIngestion.where(source_id: sources.map(&:id))
      .order(created_at: :desc)
      .group_by(&:source_id)
      .transform_values(&:first)
  end

  def load_navigation_context
    @navigation_context = Admin::Runs::NavigationContext.new(params: params, session: session).resolve
  end
end
