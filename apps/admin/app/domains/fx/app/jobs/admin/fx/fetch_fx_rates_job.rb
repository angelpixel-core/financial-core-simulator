# frozen_string_literal: true

require "securerandom"

class Admin::Fx::FetchFxRatesJob < ApplicationJob
  queue_as :default

  def perform(source_id, correlation_id: nil, causation_id: nil)
    source = FxRateSource.find(source_id)
    correlation_id ||= SecureRandom.uuid
    ingestion = FxRateIngestion.create!(
      source: source,
      status: "running",
      correlation_id: correlation_id,
      causation_id: causation_id,
      started_at: Time.current
    )

    metrics.increment("fcs_fx_ingestion_started_total", tags: metrics_tags(source))

    adapter = Admin::Fx::Ingestion::AdapterRegistry.build(source)
    return fail_ingestion(ingestion, "adapter_missing", source: source) if adapter.nil?

    date_from, date_to = adapter.default_range
    fetch_result = adapter.fetch(date_from: date_from, date_to: date_to)

    if fetch_result.failure?
      return fail_ingestion(ingestion, fetch_result.error_code, source: source,
        context: fetch_result.context, event_type: "fx_rate.fetch_failed")
    end

    payload = fetch_result.data.fetch(:payload)
    record_count = payload.dig("metadata", "resultset", "count")
    emit_event(
      ingestion: ingestion,
      event_type: "fx_rate.ingested",
      data: {
        record_count: record_count,
        date_from: date_from.to_s,
        date_to: date_to.to_s,
        base_currency: source.config["base_currency"],
        quote_currency: source.config["quote_currency"],
        source_code: source.code
      }
    )

    contract = Admin::Fx::Ingestion::Validators::BcraContract.new
    validation = contract.call(payload)
    unless validation.success?
      sample, payload_size = sample_payload(payload)
      return fail_ingestion(ingestion, "validation_failed", source: source,
        context: {errors: validation.errors.to_h, sample: sample, payload_size: payload_size},
        event_type: "fx_rate.validation_failed")
    end

    emit_event(
      ingestion: ingestion,
      event_type: "fx_rate.persisted",
      data: {
        record_count: record_count,
        date_from: date_from.to_s,
        date_to: date_to.to_s,
        base_currency: source.config["base_currency"],
        quote_currency: source.config["quote_currency"],
        source_code: source.code
      }
    )

    ingestion.update!(status: "success", finished_at: Time.current)
    metrics.increment("fcs_fx_ingestion_success_total", tags: metrics_tags(source))
  rescue => e
    if ingestion.present?
      ingestion.update!(status: "failed", error_code: "job_error", context: {message: e.message},
        finished_at: Time.current)
    end
    metrics.increment("fcs_fx_ingestion_failed_total", tags: metrics_tags(source)) if source.present?
    raise
  ensure
    if ingestion.present?
      duration_ms = ((Time.current - ingestion.started_at) * 1000).to_i
      metrics.observe("fcs_fx_ingestion_duration_ms", duration_ms, tags: metrics_tags(source)) if source.present?
    end
  end

  private

  def emit_event(ingestion:, event_type:, data: {})
    event_emitter.emit(
      event_type: event_type,
      data: data,
      metadata: {
        correlation_id: ingestion.correlation_id,
        causation_id: ingestion.causation_id,
        source_id: ingestion.source_id,
        ingestion_id: ingestion.id
      }
    )
  end

  def fail_ingestion(ingestion, error_code, source:, context: {}, event_type: nil)
    ingestion.update!(status: "failed", error_code: error_code, context: context, finished_at: Time.current)

    if event_type.present?
      emit_event(
        ingestion: ingestion,
        event_type: event_type,
        data: {
          error_code: error_code,
          sample: context[:sample],
          error_count: context[:errors].is_a?(Hash) ? context[:errors].length : nil,
          payload_size: context[:payload_size]
        }.compact
      )
    end

    metrics.increment("fcs_fx_ingestion_failed_total", tags: metrics_tags(source))
    + metrics.increment("fcs_fx_ingestion_validation_failed_total", tags: metrics_tags(source)) if error_code == "validation_failed"
  end

  def sample_payload(payload)
    results = payload["results"] || []
    size = results.size
    sample = (size <= 10) ? results : results.first(3)
    [sample, size]
  end

  def metrics_tags(source)
    {
      source_code: source.code,
      base_currency: source.config["base_currency"],
      quote_currency: source.config["quote_currency"]
    }
  end

  def event_emitter
    Admin::Fx::Ingestion::EventEmitter.new(
      publisher: publisher,
      publish_enabled: publish_enabled?
    )
  end

  def publisher
    FCS::Application::Base::NoopPublisher.new(enabled: publish_enabled?)
  end

  def publish_enabled?
    Rails.configuration.x.fx_event_publish_enabled == true
  end

  def metrics
    FCS::Application::Base::NoopMetrics.new
  end
end
