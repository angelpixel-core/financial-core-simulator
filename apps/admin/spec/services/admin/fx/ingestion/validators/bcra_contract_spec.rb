require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::Validators::BcraContract do
  subject(:contract) { described_class.new }

  let(:valid_payload) do
    {
      status: 200,
      metadata: {
        resultset: {
          count: 1,
          offset: 0,
          limit: 1000
        }
      },
      results: [
        {
          fecha: "2024-06-12",
          detalle: [
            {
              codigoMoneda: "USD",
              descripcion: "Dolar",
              tipoPase: "1.12940000",
              tipoCotizacion: "49.32089800"
            }
          ]
        }
      ]
    }
  end

  it "accepts valid payloads" do
    result = contract.call(valid_payload)

    expect(result).to be_success
  end

  it "accepts empty results" do
    payload = valid_payload.merge(results: [], metadata: {resultset: {count: 0, offset: 0, limit: 1000}})

    result = contract.call(payload)

    expect(result).to be_success
  end

  it "rejects invalid field types" do
    payload = valid_payload.merge(status: "200")

    result = contract.call(payload)

    expect(result).to be_failure
    expect(result.errors.to_h).to include(status: ["must be an integer"])
  end

  it "requires required keys" do
    payload = valid_payload.merge(metadata: nil)

    result = contract.call(payload)

    expect(result).to be_failure
    expect(result.errors.to_h).to include(metadata: ["must be a hash"])
  end
end
