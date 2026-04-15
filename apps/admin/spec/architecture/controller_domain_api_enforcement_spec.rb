require 'rails_helper'

RSpec.describe 'Controller domain API boundaries' do
  ROOT = Rails.root

  def read_controller(relative_path)
    File.read(ROOT.join(relative_path))
        .lines
        .reject { |line| line.lstrip.start_with?('class ') }
        .join
  end

  it 'keeps FX controllers on Admin::Fx::Api' do
    files = [
      'app/controllers/admin/fx/daily_rates_controller.rb',
      'app/controllers/admin/fx/rate_uploads_controller.rb',
      'app/controllers/admin/fx/history_controller.rb',
      'app/controllers/admin/fx/reporting_settings_controller.rb'
    ]

    files.each do |relative_path|
      content = read_controller(relative_path)
      expect(content).not_to match(/Admin::Fx::(?!Api\b)/), "Expected #{relative_path} to use Admin::Fx::Api only"
    end
  end

  it 'keeps demo dataset controllers on Admin::DemoDataset::Api' do
    files = [
      'app/controllers/admin/demo_datasets_controller.rb',
      'app/controllers/demo_datasets_controller.rb'
    ]

    files.each do |relative_path|
      content = read_controller(relative_path)
      expect(content).not_to match(/Admin::DemoDataset::(?!Api\b)/),
                             "Expected #{relative_path} to use Admin::DemoDataset::Api only"
    end
  end

  it 'keeps run execution/verification controllers on Runs::Api' do
    files = [
      'app/controllers/run_executions_controller.rb',
      'app/controllers/run_verifications_controller.rb'
    ]

    files.each do |relative_path|
      content = read_controller(relative_path)
      expect(content).not_to match(/Runs::(?!Api\b)/), "Expected #{relative_path} to use Runs::Api only"
    end
  end
end
