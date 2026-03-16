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

  it "memoizes the default logger and writes to stderr" do
    original_logger = FCS.logger
    original_stderr = $stderr
    io = StringIO.new

    begin
      $stderr = io
      FCS.logger = nil

      default_logger = FCS.logger
      expect(default_logger).to be_a(FCS::Logging::SimpleLogger)
      expect(default_logger.level).to eq(FCS::Logging::SimpleLogger::WARN)

      default_logger.warn("hello")
      expect(io.string).to include("hello")

      expect(FCS.logger).to be(default_logger)
    ensure
      FCS.logger = original_logger
      $stderr = original_stderr
    end
  end
end
