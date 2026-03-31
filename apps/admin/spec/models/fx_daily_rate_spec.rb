require 'rails_helper'

RSpec.describe FxDailyRate, type: :model do
  describe 'placeholder validations' do
    it 'allows placeholder rates without a numeric value' do
      rate = described_class.new(
        operational_date: Date.new(2026, 3, 30),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: nil,
        source: 'placeholder'
      )

      expect(rate).to be_valid
    end

    it 'rejects placeholder rates with a numeric value' do
      rate = described_class.new(
        operational_date: Date.new(2026, 3, 30),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: '1.5',
        source: 'placeholder'
      )

      expect(rate).not_to be_valid
      expect(rate.errors[:rate]).to include('must be blank for placeholder')
    end

    it 'requires a rate for manual sources' do
      rate = described_class.new(
        operational_date: Date.new(2026, 3, 30),
        base_currency: 'USD',
        quote_currency: 'ARS',
        rate: nil,
        source: 'manual'
      )

      expect(rate).not_to be_valid
      expect(rate.errors[:rate]).to include('is required')
    end
  end
end
