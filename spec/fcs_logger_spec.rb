# frozen_string_literal: true

require_relative '../lib/fcs'
require 'stringio'

RSpec.describe 'FCS.logger' do
  it 'provides a configurable logger with WARN default level' do
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

  it 'memoizes the default logger and writes to stderr' do
    original_logger = FCS.logger
    default_logger = nil

    expect do
      FCS.logger = nil
      default_logger = FCS.logger
      default_logger.warn('hello')
    end.to output(/hello/).to_stderr

    expect(default_logger).to be_a(FCS::Logging::SimpleLogger)
    expect(default_logger.level).to eq(FCS::Logging::SimpleLogger::WARN)
    expect(FCS.logger).to be(default_logger)
  ensure
    FCS.logger = original_logger
  end

  it 'uses the fully qualified logger class and WARN constant' do
    original_logger = FCS.logger
    original_class = FCS.logger_class
    logger_double = instance_spy(FCS::Logging::SimpleLogger, level: nil)
    custom_class = class_double(FCS::Logging::SimpleLogger)

    stub_const('Logging::SimpleLogger', Class.new do
      WARN = -1
    end)

    allow(custom_class).to receive(:new).with(io: $stderr).and_return(logger_double)

    begin
      FCS.logger = nil
      FCS.logger_class = custom_class

      FCS.logger

      expect(custom_class).to have_received(:new).with(io: $stderr)
      expect(logger_double).to have_received(:level=).with(FCS::Logging::SimpleLogger::WARN)
    ensure
      FCS.logger = original_logger
      FCS.logger_class = original_class
    end
  end
end
