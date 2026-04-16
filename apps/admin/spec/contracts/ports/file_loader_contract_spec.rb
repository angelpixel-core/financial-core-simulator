require "rails_helper"

RSpec.describe "File loader port contract" do
  it "is satisfied by demo dataset file adapter" do
    parser_result = Struct.new(:valid?, :input, :errors, keyword_init: true).new(
      valid?: false,
      input: {schemaVersion: "1.0", trades: []},
      errors: [
        {"line" => 4, "code" => "INVALID_SIDE", "message" => "invalid side"}
      ]
    )
    parser = class_double(Admin::DemoDataset::ExcelToInputParser)
    allow(parser).to receive(:call).with(file_path: "/tmp/sample.xlsx",
      timeline_enabled: true).and_return(parser_result)

    adapter = Admin::Demo::Datasets::FileAdapter.new(parser: parser)

    expect(adapter).to be_a(FCS::Ports::FileLoader)

    result = adapter.load(file_path: "/tmp/sample.xlsx", timeline_enabled: true)

    expect(result.valid?).to be(false)
    expect(result.input).to include(schemaVersion: "1.0")
    expect(result.errors).to eq([
      {line: 4, code: "INVALID_SIDE", message: "invalid side"}
    ])
  end
end
