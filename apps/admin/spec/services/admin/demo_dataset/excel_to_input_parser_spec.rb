require "rails_helper"
require "tempfile"

RSpec.describe Admin::Demo::Datasets::ExcelToInputParser do
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

  it "returns missing field errors for invalid timestamps" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-3,account-3,ETH-USD,not-a-timestamp,1,BUY,1.0,99.5
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

  it "keeps valid trades when some rows are invalid" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-4,account-4,ETH-USD,1700000000,1,BUY,1.0,120.0
      trade-5,account-5,ETH-USD,1700000001,2,HOLD,1.0,130.0
    CSV

    tempfile = write_csv(csv)

    begin
      result = described_class.call(file_path: tempfile.path)

      expect(result.valid?).to eq(false)
      expect(result.input[:trades].map { |trade| trade[:tradeId] }).to eq(["trade-4"])
      expect(result.errors).to include(hash_including(line: 3, code: "INVALID_SIDE", trade_id: "trade-5"))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "rejects files above maximum size" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-1,account-1,ETH-USD,1700000000,1,BUY,1.0,120.0
    CSV

    tempfile = write_csv(csv)

    begin
      allow(File).to receive(:size).and_call_original
      allow(File).to receive(:size).with(tempfile.path).and_return(described_class::MAX_FILE_SIZE_BYTES + 1)

      result = described_class.call(file_path: tempfile.path)

      expect(result.valid?).to eq(false)
      expect(result.input[:trades]).to eq([])
      expect(result.errors).to include(hash_including(code: "FILE_SIZE_EXCEEDED"))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "stops parsing when max rows limit is exceeded" do
    stub_const("Admin::Demo::Datasets::ExcelToInputParser::MAX_ROWS", 2)
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-1,account-1,ETH-USD,1700000000,1,BUY,1.0,120.0
      trade-2,account-2,ETH-USD,1700000001,2,BUY,1.0,121.0
      trade-3,account-3,ETH-USD,1700000002,3,BUY,1.0,122.0
    CSV

    tempfile = write_csv(csv)

    begin
      result = described_class.call(file_path: tempfile.path)

      expect(result.valid?).to eq(false)
      expect(result.input[:trades].map { |trade| trade[:tradeId] }).to eq(%w[trade-1 trade-2])
      expect(result.errors).to include(hash_including(code: "MAX_ROWS_EXCEEDED"))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
