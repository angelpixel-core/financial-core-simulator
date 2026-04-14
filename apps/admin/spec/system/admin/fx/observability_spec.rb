require "rails_helper"
require "capybara/rspec"
require "bcrypt"
require "json"
require_relative "../../../support/system_helpers"

RSpec.describe "Admin FX observability", type: :system do
  around do |example|
    previous_token = ENV["ADMIN_UI_TOKEN"]
    ENV["ADMIN_UI_TOKEN"] = nil
    example.run
  ensure
    ENV["ADMIN_UI_TOKEN"] = previous_token
  end

  around do |example|
    travel_to(Time.zone.parse("2026-04-10 09:00:00")) { example.run }
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )
    Account.create!(
      email: "admin@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )
  end

  shared_examples "observability filters" do |email|
    it "renders and filters for #{email}" do
      seed_observability_data

      login(email)
      visit "/admin/fx/observability"
      wait_for_app_shell

      source_label = I18n.t("admin.fx.observability.filter.label")
      range_label = I18n.t("admin.fx.observability.filter.range_label")

      expect(page).to have_select(source_label, wait: 10)
      expect(page).to have_select(range_label, wait: 10)

      select "Banco Central", from: source_label
      expect(success_chart_points).to include("label" => "Banco Central", "success" => 1, "failed" => 1)

      select I18n.t("admin.fx.observability.filter.range_14d"), from: range_label
      expect(success_chart_points).to include("label" => "Banco Central", "success" => 2, "failed" => 1)
    end
  end

  include_examples "observability filters", "ops@example.com"
  include_examples "observability filters", "admin@example.com"

  def login(email)
    visit "/admin/login"
    fill_in "admin-login-email", with: email
    fill_in "admin-login-password", with: "secret-pass"
    click_button I18n.t("admin.auth.form.submit")
    wait_for_app_shell
  end

  def seed_observability_data
    source_a = FxRateSource.create!(
      name: "Banco Central",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://example.com",
        "currency_code" => "USD"
      }
    )
    source_b = FxRateSource.create!(
      name: "Alternate Source",
      code: "ALT",
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://example.com",
        "currency_code" => "USD"
      }
    )

    FxRateIngestion.create!(source: source_a, status: "success", correlation_id: "c1",
      created_at: Time.zone.parse("2026-04-09 10:00:00"))
    FxRateIngestion.create!(source: source_a, status: "failed", error_code: "http_error",
      correlation_id: "c2", created_at: Time.zone.parse("2026-04-09 11:00:00"))
    FxRateIngestion.create!(source: source_a, status: "success", correlation_id: "c3",
      created_at: Time.zone.parse("2026-03-31 10:00:00"))

    FxRateIngestion.create!(source: source_b, status: "success", correlation_id: "c4",
      created_at: Time.zone.parse("2026-04-09 12:00:00"))
  end

  def success_chart_points
    chart = find(:xpath,
      "//div[@data-controller='fx--observability--chart' and contains(@data-fx--observability--chart-series-value, '\"success\"')]",
      wait: 10)
    JSON.parse(chart["data-fx--observability--chart-points-value"])
  end
end
