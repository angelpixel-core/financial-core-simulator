require "rails_helper"

RSpec.describe Admin::Fx::RateUploadJob, type: :job do
  it "imports all template rows and completes without broadcast render errors" do
    template = Admin::Fx::RateUploadTemplate.generate
    file = Tempfile.new(["fx-rates", ".xlsx"])
    file.binmode
    file.write(template.data)
    file.flush

    upload = FxRateUpload.create!(
      status: "processing",
      created_by_id: "1",
      created_by_role: "admin",
      created_context: {"locale" => "en", "source" => "fx_history_upload"},
      original_filename: "fx_rates_template.xlsx",
      file_path: file.path
    )

    expect { described_class.perform_now(upload.id) }.not_to raise_error

    upload.reload
    expect(upload.status).to eq("success")
    expect(FxDailyRate.where(source_upload_id: upload.id).count).to eq(150)
  ensure
    file_path = file&.path
    file&.close
    file&.unlink if file_path && File.exist?(file_path)
  end
end
