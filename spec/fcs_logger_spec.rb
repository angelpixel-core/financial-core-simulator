# frozen_string_literal: true

require_relative "../lib/fcs"
require "stringio"

RSpec.describe "FCS.logger" do
  it "provides a configurable logger with WARN default level" do
    original_logger = FCS.logger

    io = StringIO.new
    custom_logger = FCS::Logging::SimpleLogger.new(io: io)
    custom_logger.level = FCS::Logging::SimpleLogger::ERROR

    FCS.logger = custom_logger

    expect(FCS.logger).to be(custom_logger)
    expect(FCS.logger.level).to eq(FCS::Logging::SimpleLogger::ERROR)

    FCS.logger = nil
    expect(FCS.logger.level).to eq(FCS::Logging::SimpleLogger::WARN)

    FCS.logger = original_logger
  end
end
