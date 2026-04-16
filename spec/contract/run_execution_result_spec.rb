# frozen_string_literal: true

require_relative '../../lib/fcs'

RSpec.describe FCS::Contracts::RunExecutionResult do
  it 'builds the run execution result contract' do
    result = described_class.from_hash!(
      input_hash: 'a' * 64,
      run_id: '123e4567-e89b-5d3a-a456-426614174000',
      schema_version: '1.0',
      valuation_timestamp: '2026-04-15T10:00:00Z',
      payload: { 'accounts' => [] },
      artifacts: { json_path: 'tmp/out/result.json' }
    )

    expect(result).to include(
      input_hash: 'a' * 64,
      run_id: '123e4567-e89b-5d3a-a456-426614174000',
      schema_version: '1.0',
      valuation_timestamp: '2026-04-15T10:00:00Z',
      payload: { 'accounts' => [] },
      artifacts: { json_path: 'tmp/out/result.json' }
    )
  end

  it 'raises when required fields are missing' do
    expect do
      described_class.from_hash!(
        input_hash: 'a' * 64
      )
    end.to raise_error(ArgumentError, /Missing required fields/)
  end
end
