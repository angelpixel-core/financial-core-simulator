require 'swagger_helper'

RSpec.describe 'Admin FX API', type: :request do
  let(:admin_headers) do
    {
      'X-Admin-User' => 'alice',
      'X-Admin-Role' => 'operator'
    }
  end

  path '/admin/fx/ingestions/sync' do
    post 'Queue FX ingestion' do
      tags 'FX'
      produces 'application/json'
      parameter name: 'X-Admin-User', in: :header, type: :string, required: true
      parameter name: 'X-Admin-Role', in: :header, type: :string, required: true
      parameter name: :source_id, in: :query, type: :integer, required: true
      parameter name: :market, in: :query, type: :string, required: true
      security [{ AdminUser: [], AdminRole: [] }]

      response '200', 'queued' do
        schema({ '$ref' => '#/components/schemas/FxIngestion' })

        let(:source) do
          FxRateSource.create!(
            name: 'Banco Central',
            code: 'BCRA',
            source_type: 'api',
            version: 'v1',
            config: {
              'base_currency' => 'USD',
              'quote_currency' => 'ARS',
              'base_url' => 'https://api.bcra.gob.ar/estadisticascambiarias/v1.0',
              'currency_code' => 'USD'
            }
          )
        end
        let(:source_id) { source.id }
        let(:market) { 'USDARS' }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        before do
          allow(Admin::Fx::FetchFxRatesJob).to receive(:perform_later)
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['status']).to eq('queued')
        end
      end

      response '422', 'invalid request' do
        schema type: :object
        let(:source_id) { nil }
        let(:market) { 'USDARS' }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '500', 'server error' do
        schema type: :object

        before do
          allow(Admin::Fx::FetchFxRatesJob).to receive(:perform_later).and_raise(StandardError, 'boom')
        end

        let(:source_id) do
          FxRateSource.create!(name: 'BCRA', code: 'BCRA', source_type: 'api', version: 'v1',
                               config: { 'base_currency' => 'USD', 'quote_currency' => 'ARS' }).id
        end
        let(:market) { 'USDARS' }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end
    end
  end

  path '/admin/fx/history' do
    get 'FX history' do
      tags 'FX'
      produces 'application/json'
      parameter name: 'X-Admin-User', in: :header, type: :string, required: true
      parameter name: 'X-Admin-Role', in: :header, type: :string, required: true
      parameter name: :source_id, in: :query, type: :integer, required: false
      security [{ AdminUser: [], AdminRole: [] }]

      response '200', 'history payload' do
        schema({ '$ref' => '#/components/schemas/FxHistoryResponse' })

        before do
          FxRateSource.create!(
            name: 'Banco Central',
            code: 'BCRA',
            source_type: 'api',
            version: 'v1',
            config: {
              'base_currency' => 'USD',
              'quote_currency' => 'ARS',
              'base_url' => 'https://api.bcra.gob.ar/estadisticascambiarias/v1.0',
              'currency_code' => 'USD'
            }
          )
        end

        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object
        let(:source_id) { 999_999 }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '500', 'server error' do
        schema type: :object
        before do
          allow(Admin::Fx::HistorySnapshot).to receive(:call).and_raise(StandardError, 'boom')
        end
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end
    end
  end

  path '/admin/fx/observability' do
    get 'FX observability' do
      tags 'FX'
      produces 'application/json'
      parameter name: 'X-Admin-User', in: :header, type: :string, required: true
      parameter name: 'X-Admin-Role', in: :header, type: :string, required: true
      parameter name: :source_id, in: :query, type: :integer, required: false
      parameter name: :days, in: :query, type: :integer, required: false
      security [{ AdminUser: [], AdminRole: [] }]

      response '200', 'observability payload' do
        schema({ '$ref' => '#/components/schemas/FxObservabilityResponse' })

        before do
          FxRateSource.create!(
            name: 'Banco Central',
            code: 'BCRA',
            source_type: 'api',
            version: 'v1',
            config: {
              'base_currency' => 'USD',
              'quote_currency' => 'ARS',
              'base_url' => 'https://api.bcra.gob.ar/estadisticascambiarias/v1.0',
              'currency_code' => 'USD'
            }
          )
        end

        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object
        let(:source_id) { 999_999 }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '500', 'server error' do
        schema type: :object
        before do
          allow(Admin::Fx::ObservabilitySnapshot).to receive(:call).and_raise(StandardError, 'boom')
        end
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end
    end
  end

  path '/admin/fx/ingestions' do
    get 'List FX ingestions' do
      tags 'FX'
      produces 'application/json'
      parameter name: 'X-Admin-User', in: :header, type: :string, required: true
      parameter name: 'X-Admin-Role', in: :header, type: :string, required: true
      parameter name: :source_id, in: :query, type: :integer, required: false
      security [{ AdminUser: [], AdminRole: [] }]

      response '200', 'ingestion list' do
        schema({ '$ref' => '#/components/schemas/FxIngestionList' })

        before do
          FxRateSource.create!(
            name: 'Banco Central',
            code: 'BCRA',
            source_type: 'api',
            version: 'v1',
            config: {
              'base_currency' => 'USD',
              'quote_currency' => 'ARS',
              'base_url' => 'https://api.bcra.gob.ar/estadisticascambiarias/v1.0',
              'currency_code' => 'USD'
            }
          )
        end

        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object
        let(:source_id) { 999_999 }
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end

      response '500', 'server error' do
        schema type: :object
        before do
          allow(FxRateSource).to receive(:order).and_raise(StandardError, 'boom')
        end
        let(:"X-Admin-User") { admin_headers['X-Admin-User'] }
        let(:"X-Admin-Role") { admin_headers['X-Admin-Role'] }

        run_test!
      end
    end
  end
end
