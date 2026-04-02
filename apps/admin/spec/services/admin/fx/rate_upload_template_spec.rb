require 'rails_helper'
require 'roo'
require 'tempfile'

RSpec.describe Admin::Fx::RateUploadTemplate do
  def normalize_date(value)
    return value.to_date if value.respond_to?(:to_date)

    Date.iso8601(value.to_s)
  end

  def expected_rate_for(date, base_currency, quote_currency)
    Admin::Fx::RateUploadTemplate::RATE_BASES.fetch([base_currency, quote_currency]) + date.day
  end

  it 'generates a single-sheet March 2026 template with descending dates' do
    template = described_class.generate
    tempfile = Tempfile.new(['fx_rates_template', '.xlsx'])
    tempfile.binmode
    tempfile.write(template.data)
    tempfile.flush

    begin
      workbook = Roo::Spreadsheet.open(tempfile.path)
      expect(workbook.sheets.size).to eq(1)

      sheet = workbook.sheet(workbook.sheets.first)
      expect(sheet.row(1).map(&:to_s)).to eq(Admin::Fx::RateUploadTemplate::HEADERS)

      data_rows = (2..sheet.last_row).map { |line| sheet.row(line) }
      ids = data_rows.map { |row| row[0].to_s }
      dates = data_rows.map { |row| normalize_date(row[1]) }
      data_rows.map { |row| [row[2].to_s, row[3].to_s] }
      rates = data_rows.map { |row| row[4] }

      expect(ids).to all(be_present)
      expect(ids.uniq.size).to eq(ids.size)

      expected_dates = (Date.new(2026, 3, 1)..Date.new(2026, 3, 30)).to_a
      expect(dates.uniq).to match_array(expected_dates)
      expect(dates).to eq(dates.sort.reverse)

      expected_pairs = Admin::Fx::RateUploadTemplate::TEMPLATE_PAIRS
      grouped_pairs = data_rows.group_by { |row| normalize_date(row[1]) }
                               .transform_values do |rows|
        rows.map do |row|
          [row[2].to_s, row[3].to_s]
        end
      end

      grouped_pairs.each_value do |date_pairs|
        expect(date_pairs).to eq(expected_pairs)
      end

      expect(rates).to all(be_present)
      expect(rates).to all(be_a(Numeric))

      data_rows.each do |row|
        date = normalize_date(row[1])
        base_currency = row[2].to_s
        quote_currency = row[3].to_s
        rate = row[4]

        expect(rate).to be_within(0.0001).of(expected_rate_for(date, base_currency, quote_currency))
      end
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
