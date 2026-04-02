require "rails_helper"
require "tempfile"

RSpec.describe Admin::DemoDataset::ExcelToInputParser do
  def write_csv(contents)
    tempfile = Tempfile.new(["demo_dataset", ".csv"])
    tempfile.write(contents)
    tempfile.flush
    tempfile
  end

  it "ignores extra cells beyond the headers" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-1,account-1,ETH-USD,1700000000,1,BUY,1.5,100.25,EXTRA,EXTRA2
    CSV

    tempfile = write_csv(csv)

    begin
      result = described_class.call(file_path: tempfile.path)

      expect(result.errors).to be_empty
      expect(result.input[:trades].size).to eq(1)
      expect(result.input[:trades].first[:tradeId]).to eq("trade-1")
      expect(result.input[:trades].first[:priceQuotePerBase]).to eq("100.25")
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "handles shorter rows without raising" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-2,account-2,ETH-USD
    CSV

    tempfile = write_csv(csv)

    begin
      result = described_class.call(file_path: tempfile.path)

      expect(result.errors).to include(hash_including(line: 2, code: "MISSING_FIELDS"))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
