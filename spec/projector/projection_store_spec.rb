require_relative '../../lib/fcs'

RSpec.describe FCS::Projector::ProjectionStore do
  class StubProjection
    attr_reader :applied, :read_model

    def initialize(read_model)
      @read_model = read_model
      @applied = []
    end

    def apply!(event)
      @applied << event
      true
    end
  end

  describe '#apply!' do
    it 'applies the event to each selected projection in order' do
      overview = StubProjection.new('overviewKpi' => { 'queued' => 1 })
      trend = StubProjection.new('runsTrend14d' => [])
      store = described_class.new(projections: { 'overview' => overview, 'trend' => trend })

      event = { 'eventType' => 'RUN_LIFECYCLE_NORMALIZED', 'payload' => {} }
      store.apply!(%w[overview trend], event)

      expect(overview.applied).to eq([event])
      expect(trend.applied).to eq([event])
    end

    it 'rejects unknown projection keys' do
      store = described_class.new(projections: { 'overview' => StubProjection.new({}) })

      expect do
        store.apply!(%w[missing], { 'eventType' => 'RUN_LIFECYCLE_NORMALIZED', 'payload' => {} })
      end.to raise_error(FCS::Error) { |error| expect(error.details).to include(field: 'projectionStore.projections.missing') }
    end
  end

  describe '#read_model' do
    it 'composes read-model fragments deterministically' do
      store = described_class.new(
        projections: {
          'overview' => StubProjection.new('overviewKpi' => { 'queued' => 1 }),
          'trend' => StubProjection.new('runsTrend14d' => [{ 'day' => '03-04', 'count' => 2 }]),
          'topAccountsRisk' => StubProjection.new('topAccounts' => [{ 'accountId' => 'acc-a' }], 'riskView' => {})
        }
      )

      expect(store.read_model).to eq(
        'overviewKpi' => { 'queued' => 1 },
        'runsTrend14d' => [{ 'day' => '03-04', 'count' => 2 }],
        'topAccounts' => [{ 'accountId' => 'acc-a' }],
        'riskView' => {}
      )
    end
  end

  describe 'projection validation' do
    it 'rejects projections that do not satisfy the interface' do
      expect do
        described_class.new(projections: { 'overview' => Object.new })
      end.to raise_error(FCS::Error) do |error|
        expect(error.details).to include(field: 'projectionStore.projections.overview')
      end
    end
  end
end
