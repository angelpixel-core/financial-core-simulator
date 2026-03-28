# frozen_string_literal: true

class DemoDatasetsController < ApplicationController
  def valid
    send_dataset(:valid)
  end

  def invalid
    send_dataset(:invalid)
  end

  private

  def send_dataset(kind)
    generator = Admin::DemoDataset::ExcelGenerator.new(output_dir: output_dir)
    path = kind == :invalid ? generator.generate_invalid : generator.generate_valid
    send_file path, filename: File.basename(path), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def output_dir
    Rails.root.join("tmp", "excels").to_s
  end
end
