require 'rails_helper'
require 'roo'
require 'tempfile'

RSpec.describe Admin::Fx::RateUploadTemplate do
  def normalize_date(value)
    return value.to_date if value.respond_to?(:to_date)

    Date.iso8601(value.to_s)
  end

  it 'generates template rows with a partial second day' do
    template = described_class.generate
    tempfile = Tempfile.new(['fx_rates_template', '.xlsx'])
    tempfile.binmode
    tempfile.write(template.data)
    tempfile.flush

    workbook = Roo::Spreadsheet.open(tempfile.path)
    expected_sheet_names = Admin::Fx::RunRateGapProcessor::SUPPORTED_PAIRS.map { |pair| pair.join('-') }

    expect(workbook.sheets).to match_array(expected_sheet_names)

    usd_ars = workbook.sheet('USD-ARS')
    expect(usd_ars.row(1).map(&:to_s)).to eq(Admin::Fx::RateUploadTemplate::HEADERS)
    expect(usd_ars.last_row).to eq(3)
    expect(normalize_date(usd_ars.row(2)[0])).to eq(Date.new(2026, 3, 30))
    expect(normalize_date(usd_ars.row(3)[0])).to eq(Date.new(2026, 3, 31))

    %w[BTC-USD BTC-ARS ETH-USD ETH-ARS].each do |sheet_name|
      sheet = workbook.sheet(sheet_name)
      expect(sheet.last_row).to eq(2)
      expect(normalize_date(sheet.row(2)[0])).to eq(Date.new(2026, 3, 30))
    end
  ensure
    tempfile.close
    tempfile.unlink
  end
end
