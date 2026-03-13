require_relative '../../lib/fcs'

RSpec.describe FCS::Engine::Position do
  it 'rejects BUY with zero quantity defensively' do
    position = described_class.empty

    expect do
      position.apply_buy!(
        buy_qty: FCS::Types::Decimal18.new(0),
        buy_price: FCS::Types::Decimal18.from_string('100')
      )
    end.to raise_error(FCS::Error) { |error| expect(error.code).to eq(FCS::Errors::ERR_VALIDATION) }
  end
end
