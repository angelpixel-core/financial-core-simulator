require "rails_helper"

RSpec.describe Admin::Fx::RateUploadImporter do
  def write_csv(contents)
    tempfile = Tempfile.new(["fx_upload", ".csv"])
    tempfile.write(contents)
    tempfile.flush
    tempfile
  end

  it "rejects files above max size" do
    csv = <<~CSV
      id,operational_date,base_currency,quote_currency,rate
      1,2026-03-30,USD,ARS,1000.0
    CSV

    tempfile = write_csv(csv)

    begin
      allow(File).to receive(:size).and_call_original
      allow(File).to receive(:size).with(tempfile.path).and_return(described_class::MAX_FILE_SIZE_BYTES + 1)

      result = described_class.call(
        file_path: tempfile.path,
        created_by_id: 1,
        created_by_role: "operator",
        created_context: {"source" => "spec"}
      )

      expect(result.valid?).to eq(false)
      expect(result.errors).to include(hash_including(code: "FILE_SIZE_EXCEEDED"))
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "stops parsing when max rows limit is exceeded" do
    stub_const("Admin::Fx::RateUploadImporter::MAX_ROWS", 2)
    csv = <<~CSV
      id,operational_date,base_currency,quote_currency,rate
      1,2026-03-29,USD,ARS,1000.0
      2,2026-03-30,USD,ARS,1001.0
      3,2026-03-31,USD,ARS,1002.0
    CSV

    tempfile = write_csv(csv)

    begin
      allow(Admin::Fx::RateUpserter).to receive(:call)

      result = described_class.call(
        file_path: tempfile.path,
        created_by_id: 1,
        created_by_role: "operator",
        created_context: {"source" => "spec"}
      )

      expect(result.valid?).to eq(false)
      expect(result.errors).to include(hash_including(code: "MAX_ROWS_EXCEEDED"))
      expect(Admin::Fx::RateUpserter).not_to have_received(:call)
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  it "persists valid rows in batches" do
    stub_const("Admin::Fx::RateUploadImporter::BATCH_SIZE", 2)
    csv = <<~CSV
      id,operational_date,base_currency,quote_currency,rate
      1,2026-03-29,USD,ARS,1000.0
      2,2026-03-30,USD,ARS,1001.0
      3,2026-03-31,USD,ARS,1002.0
    CSV

    tempfile = write_csv(csv)

    begin
      allow(Admin::Fx::RateUpserter).to receive(:call)

      result = described_class.call(
        file_path: tempfile.path,
        created_by_id: 1,
        created_by_role: "operator",
        created_context: {"source" => "spec"}
      )

      expect(result.valid?).to eq(true)
      expect(result.errors).to eq([])
      expect(Admin::Fx::RateUpserter).to have_received(:call).exactly(3).times
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
