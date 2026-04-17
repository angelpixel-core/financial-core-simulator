require 'rails_helper'

RSpec.describe Admin::Dashboard::ReadMetrics do
  it 'uses artifact provider when BFF read flag is disabled' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics')
    artifact_reader = instance_double('Admin::DashboardMetrics')
    allow(artifact_reader).to receive(:call).with(trades_window: 'all-time').and_return({ total_runs_7d: 7 })

    metrics = described_class.new(env: { 'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '0' }, bff_reader: bff_reader,
                                  artifact_reader: artifact_reader).call

    expect(metrics).to eq(total_runs_7d: 7)
  end

  it 'uses BFF provider when BFF read flag is enabled' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics', call: { total_runs_7d: 9 })
    artifact_reader = instance_double('Admin::DashboardMetrics')

    metrics = described_class.new(env: { 'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '1' }, bff_reader: bff_reader,
                                  artifact_reader: artifact_reader).call

    expect(metrics).to eq(total_runs_7d: 9)
  end

  it 'falls back to artifact provider when BFF fails and fallback is enabled' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics')
    allow(bff_reader).to receive(:call).and_raise(StandardError, 'bff unavailable')
    artifact_reader = instance_double('Admin::DashboardMetrics')
    allow(artifact_reader).to receive(:call).with(trades_window: 'all-time').and_return({ total_runs_7d: 3 })

    metrics = described_class.new(
      env: {
        'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '1',
        'ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED' => '1'
      },
      bff_reader: bff_reader,
      artifact_reader: artifact_reader
    ).call

    expect(metrics).to eq(total_runs_7d: 3)
  end

  it 'raises read-path unavailable when BFF fails and fallback is disabled' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics')
    allow(bff_reader).to receive(:call).and_raise(StandardError, 'bff unavailable')
    artifact_reader = instance_double('Admin::DashboardMetrics')

    expect do
      described_class.new(env: { 'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '1' }, bff_reader: bff_reader,
                          artifact_reader: artifact_reader).call
    end.to raise_error(described_class::ReadPathUnavailableError,
                       'BFF read failed and fallback is disabled: bff unavailable')
  end

  it 'raises read-path unavailable when BFF fails and fallback is explicitly disabled' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics')
    allow(bff_reader).to receive(:call).and_raise(StandardError, 'bff unavailable')
    artifact_reader = instance_double('Admin::DashboardMetrics')

    expect do
      described_class.new(
        env: {
          'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '1',
          'ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED' => '0'
        },
        bff_reader: bff_reader,
        artifact_reader: artifact_reader
      ).call
    end.to raise_error(described_class::ReadPathUnavailableError,
                       'BFF read failed and fallback is disabled: bff unavailable')
  end

  it 'forwards trades window to artifact provider' do
    bff_reader = instance_double('Admin::Dashboard::BffReadMetrics')
    artifact_reader = instance_double('Admin::DashboardMetrics')
    allow(artifact_reader).to receive(:call).with(trades_window: '60d').and_return({ total_runs_7d: 5 })

    metrics = described_class.new(env: { 'ADMIN_DASHBOARD_BFF_READ_ENABLED' => '0' }, bff_reader: bff_reader,
                                  artifact_reader: artifact_reader).call(trades_window: '60d')

    expect(metrics).to eq(total_runs_7d: 5)
  end
end
