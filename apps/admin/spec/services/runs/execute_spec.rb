require 'rails_helper'
require 'json'

RSpec.describe Runs::Execute do
  let(:service) { described_class.new }

  let(:input_json) do
    {
      'schemaVersion' => '1.0',
      'accounts' => [{ 'accountId' => 'acc-1' }],
      'markets' => [{ 'marketId' => 'ETH-USD' }],
      'feeModel' => { 'enabled' => true },
      'trades' => [],
      'priceSnapshot' => {
        'valuationTimestamp' => '2026-02-25T03:00:00Z',
        'prices' => [{ 'marketId' => 'ETH-USD', 'priceQuotePerBase' => '150' }]
      }
    }
  end

  describe '#call' do
    it 'marks run as succeeded and persists metadata + artifact paths' do
      run = Run.create!(input_json: input_json)

      expect(Admin::Fx::RunRateGapProcessor).to receive(:call).with(run: run)

      runner = instance_double(FCS::Application::Runner)
      allow(FCS::Application::Runner).to receive(:new).and_return(runner)
      expect(runner).to receive(:run_from_input!)
        .with(input: hash_including(input_json), output_dir: kind_of(String), fee_enabled: true, explain: true, verbose: false) do |input:, output_dir:, **_kwargs|
        json_path = File.join(output_dir, 'result.json')
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              'engineVersion' => 'test-engine',
              'schemaVersion' => '1.0',
              'runId' => 'run-123',
              'inputHash' => 'abc123',
              'valuationTimestamp' => '2026-02-25T03:00:00Z',
              'global' => { 'totalPnLQuote' => '0.0' }
            }
          ) + "\n"
        )
        {
          json_path: json_path,
          annotated_input: input,
          validation_errors: [],
          reliable: true
        }
      end

      service.call(run)
      run.reload

      expect(run).to be_succeeded
      expect(run.engine_version).to eq('test-engine')
      expect(run.schema_version).to eq('1.0')
      expect(run.run_uuid).to eq('run-123')
      expect(run.input_hash).to eq('abc123')
      expect(run.valuation_timestamp).to eq(Time.zone.parse('2026-02-25T03:00:00Z'))
      expect(run.duration_ms).to be >= 0
      expect(run.result_json_path).to end_with('result.json')
      expect(run.positions_csv_path).to end_with('positions.csv')
      expect(run.pnl_csv_path).to end_with('pnl.csv')
    end

    it 'marks run as failed with error metadata when runner raises' do
      run = Run.create!(input_json: input_json)

      expect(Admin::Fx::RunRateGapProcessor).not_to receive(:call)

      runner = instance_double(FCS::Application::Runner)
      allow(FCS::Application::Runner).to receive(:new).and_return(runner)
      allow(runner).to receive(:run_from_input!).and_raise(StandardError, 'boom')

      expect { service.call(run) }.to raise_error(StandardError, 'boom')

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq('ERR_EXECUTION_FAILURE')
      expect(run.error_message).to eq('boom')
      expect(run.duration_ms).not_to be_nil
    end

    it 'maps FCS::Error code when runner raises domain error' do
      run = Run.create!(input_json: input_json)

      runner = instance_double(FCS::Application::Runner)
      allow(FCS::Application::Runner).to receive(:new).and_return(runner)
      allow(runner).to receive(:run_from_input!).and_raise(FCS::Error.new(FCS::Errors::ERR_INVALID_INPUT,
                                                                          'invalid input'))

      expect { service.call(run) }.to raise_error(FCS::Error)

      run.reload
      expect(run).to be_failed
      expect(run.error_code).to eq(FCS::Errors::ERR_INVALID_INPUT)
      expect(run.error_message).to eq('invalid input')
    end
  end
end
