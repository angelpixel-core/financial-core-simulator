# frozen_string_literal: true

require 'securerandom'

class Admin::Fx::FetchFxRatesJob < ApplicationJob
  queue_as :default

  def perform(source_id, correlation_id: nil, causation_id: nil, ingestion_id: nil, market: nil)
    ingestion = ingestion_id.present? ? FxRateIngestion.find(ingestion_id) : nil
    source = ingestion&.source || FxRateSource.find(source_id)
    correlation_id ||= ingestion&.correlation_id || SecureRandom.uuid
    ingestion ||= FxRateIngestion.create!(
      source: source,
      status: 'running',
      correlation_id: correlation_id,
      causation_id: causation_id,
      started_at: Time.current
    )
    ingestion.update!(status: 'running', started_at: Time.current)

    metrics.increment('fcs_fx_ingestion_started_total', tags: metrics_tags(source))

    adapter = Admin::Fx::Ingestion::AdapterRegistry.build(source)
    return fail_ingestion(ingestion, 'adapter_missing', source: source) if adapter.nil?

    date_from, date_to = adapter.default_range
    fetch_result = adapter.fetch(date_from: date_from, date_to: date_to)

    if fetch_result.failure?
      return fail_ingestion(ingestion, fetch_result.error_code, source: source,
                                                                context: fetch_result.context, event_type: 'fx_rate.fetch_failed')
    end

    raw_payload = fetch_result.data.fetch(:payload)
    limit = raw_payload.is_a?(Hash) ? raw_payload.dig('metadata', 'resultset', 'limit') : nil
    offset = raw_payload.is_a?(Hash) ? raw_payload.dig('metadata', 'resultset', 'offset') : nil
    payload = normalize_payload(raw_payload, status: fetch_result.metadata[:status], limit: limit,
                                             offset: offset)
    record_count = payload.dig('metadata', 'resultset', 'count')
    emit_event(
      ingestion: ingestion,
      source: source,
      event_type: 'fx_rate.ingested',
      data: {
        market: market,
        record_count: record_count,
        date_from: date_from.to_s,
        date_to: date_to.to_s,
        base_currency: source.config['base_currency'],
        quote_currency: source.config['quote_currency'],
        source_code: source.code
      }
    )

    contract = Admin::Fx::Ingestion::Validators::BcraContract.new
    validation = contract.call(payload.deep_symbolize_keys)
    unless validation.success?
      sample, payload_size = sample_payload(payload)
      return fail_ingestion(ingestion, 'validation_failed', source: source,
                                                            context: { errors: validation.errors.to_h, sample: sample, payload_size: payload_size },
                                                            event_type: 'fx_rate.validation_failed')
    end

    mapper_result = Admin::Fx::Ingestion::Mappers::BcraRateMapper.call(payload: payload, source: source)
    if mapper_result.failure?
      log_mapping_failure(ingestion: ingestion, source: source, context: mapper_result.context)
      return fail_ingestion(ingestion, 'mapping_failed', source: source,
                                                         context: mapper_result.context,
                                                         event_type: 'fx_rate.mapping_failed')
    end

    rates = mapper_result.data.fetch(:rates)
    rates.each do |rate|
      Admin::Fx::RateUpserter.call(
        **rate.to_upsert_attributes(source: 'ingestion'),
        enforce_operational_date: false,
        created_context: {
          ingestion_id: ingestion.id,
          source_code: source.code
        }
      )
    end

    emit_event(
      ingestion: ingestion,
      source: source,
      event_type: 'fx_rate.persisted',
      data: {
        market: market,
        record_count: record_count,
        persisted_count: rates.length,
        date_from: date_from.to_s,
        date_to: date_to.to_s,
        base_currency: source.config['base_currency'],
        quote_currency: source.config['quote_currency'],
        source_code: source.code
      }
    )

    ingestion.update!(status: 'success', finished_at: Time.current)
    metrics.increment('fcs_fx_ingestion_success_total', tags: metrics_tags(source))
  rescue StandardError => e
    if ingestion.present?
      error_details = Admin::Fx::Ingestion::ErrorCatalog.details_for('job_error')
      context = { message: e.message }.merge(error_details)
      ingestion.update!(status: 'failed', error_code: 'job_error', context: context,
                        finished_at: Time.current)
      log_ingestion_failure(ingestion: ingestion, source: source, context: context)
    end
    if source.present?
      metrics.increment('fcs_fx_ingestion_failed_total', tags: metrics_tags(source, error_code: 'job_error',
                                                                                    severity: 'error'))
    end
    raise
  ensure
    if ingestion.present?
      duration_ms = ((Time.current - ingestion.started_at) * 1000).to_i
      metrics.observe('fcs_fx_ingestion_duration_ms', duration_ms, tags: metrics_tags(source)) if source.present?
    end
  end

  private

  def emit_event(ingestion:, source:, event_type:, data: {}, error: {})
    event_emitter.emit_ingestion(
      event_type: event_type,
      ingestion: ingestion,
      source: source,
      data: data,
      error: error
    )
  end

  def normalize_payload(payload, status:, limit:, offset:)
    if payload.is_a?(Hash) && payload.key?('status') && payload.key?('metadata') && payload.key?('results')
      return payload
    end

    limit ||= payload.is_a?(Array) ? payload.length : 0
    offset ||= 0

    if payload.is_a?(Array)
      return {
        'status' => status,
        'metadata' => {
          'resultset' => {
            'count' => payload.length,
            'offset' => offset,
            'limit' => limit
          }
        },
        'results' => payload
      }
    end

    normalized = payload.is_a?(Hash) ? payload.dup : { 'results' => payload }
    normalized['status'] ||= status
    normalized['results'] ||= []
    normalized['metadata'] ||= {}
    normalized['metadata']['resultset'] ||= {
      'count' => normalized['results'].length,
      'offset' => offset,
      'limit' => limit
    }
    normalized
  end

  def fail_ingestion(ingestion, error_code, source:, context: {}, event_type: nil)
    error_details = Admin::Fx::Ingestion::ErrorCatalog.details_for(error_code)
    context = context.merge(error_details)
    ingestion.update!(status: 'failed', error_code: error_code, context: context, finished_at: Time.current)

    if event_type.present?
      error_count = extract_error_count(context)
      error_sample = extract_error_sample(context)
      sample = context[:sample]
      sample = JSON.generate(sample) if sample.present?
      error_sample = JSON.generate(error_sample) if error_sample.present?
      emit_event(
        ingestion: ingestion,
        source: source,
        event_type: event_type,
        data: {
          sample: sample,
          error_count: error_count,
          error_sample: error_sample,
          payload_size: context[:payload_size]
        }.compact,
        error: {
          error_code: error_code,
          severity: context[:severity],
          user_message_key: context[:user_message_key],
          action_hint_key: context[:action_hint_key],
          retryable: context[:retryable]
        }.compact
      )
    end

    log_ingestion_failure(ingestion: ingestion, source: source, context: context)

    metrics.increment('fcs_fx_ingestion_failed_total', tags: metrics_tags(source, error_code: error_code,
                                                                                  severity: context[:severity]))
    return unless error_code == 'validation_failed'

    metrics.increment('fcs_fx_ingestion_validation_failed_total',
                      tags: metrics_tags(source, error_code: error_code, severity: context[:severity]))
  end

  def sample_payload(payload)
    results = payload['results'] || []
    size = results.size
    sample = size <= 10 ? results : results.first(3)
    [sample, size]
  end

  def log_mapping_failure(ingestion:, source:, context: {})
    error_count = extract_error_count(context)
    error_sample = extract_error_sample(context)
    Rails.logger.warn(Admin::Fx::Ingestion::LogPayload.call(
      ingestion: ingestion,
      source: source,
      message: 'Fx ingestion mapping failed',
      error_code: nil,
      severity: nil,
      extra: {
        error_count: error_count,
        error_sample: error_sample
      }
    ).to_json)
  end

  def log_ingestion_failure(ingestion:, source:, context: {})
    Rails.logger.warn(Admin::Fx::Ingestion::LogPayload.call(
      ingestion: ingestion,
      source: source,
      message: 'Fx ingestion failed',
      error_code: context[:error_code],
      severity: context[:severity],
      extra: {
        retryable: context[:retryable]
      }
    ).to_json)
  end

  def extract_error_count(context)
    errors = context[:errors]
    return errors.length if errors.is_a?(Array)
    return errors.length if errors.is_a?(Hash)

    nil
  end

  def extract_error_sample(context)
    errors = context[:errors]
    return errors.first(3) if errors.is_a?(Array)

    errors.to_a.first(3) if errors.is_a?(Hash)
  end

  def metrics_tags(source, error_code: nil, severity: nil)
    {
      source_code: source.code,
      base_currency: source.config['base_currency'],
      quote_currency: source.config['quote_currency'],
      error_code: error_code,
      severity: severity
    }.compact
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
