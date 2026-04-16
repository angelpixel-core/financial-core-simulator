require "rails_helper"
require "tempfile"

RSpec.describe Admin::Demo::Datasets::FileAdapter do
  def write_csv(contents)
    tempfile = Tempfile.new(["demo_dataset_contract", ".csv"])
    tempfile.write(contents)
    tempfile.flush
    tempfile
  end

  it "parses valid input and normalizes payload shape" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-1,account-1,ETH-USD,1700000000,1,BUY,1.5,100.25
    CSV
    tempfile = write_csv(csv)

    begin
      result = described_class.new.parse(file_path: tempfile.path, timeline_enabled: true)

      expect(result.valid?).to be(true)
      expect(result.input[:schemaVersion]).to eq("1.0")
      expect(result.input[:trades]).to eq([
        {
          tradeId: "trade-1",
          accountId: "account-1",
          marketId: "ETH-USD",
          timestamp: 1_700_000_000,
          seq: 1,
          side: "BUY",
          quantityBase: "1.5",
          priceQuotePerBase: "100.25"
        }
      ])
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "maps parse/validation errors by row with normalized contract fields" do
    csv = <<~CSV
      trade_id,account_id,market_id,timestamp,seq,side,quantity_base,price_quote_per_base
      trade-1,account-1,ETH-USD,1700000000,1,BUY,1.5,100.25
      trade-2,account-1,ETH-USD,1700000001,1,SELL,1.0,100.00
      trade-3,account-1,ETH-USD,1700000002,3,HOLD,1.0,100.00
    CSV
    tempfile = write_csv(csv)

    begin
      result = described_class.new.parse(file_path: tempfile.path)

      expect(result.valid?).to be(false)
      expect(result.errors).to include(
        hash_including(line: 3, code: "SEQ_OUT_OF_ORDER"),
        hash_including(line: 4, code: "INVALID_SIDE")
      )
      expect(result.errors).to all(include(:line, :code))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
