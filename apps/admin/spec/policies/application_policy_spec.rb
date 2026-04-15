require "rails_helper"

RSpec.describe "Admin policies" do
  let(:viewer) { {id: "viewer-1", role: "viewer"} }
  let(:operator) { {id: "operator-1", role: "operator"} }
  let(:admin) { {id: "admin-1", role: "admin"} }

  it "enforces role hierarchy in application policy" do
    viewer_policy = ApplicationPolicy.new(viewer, :any)
    operator_policy = ApplicationPolicy.new(operator, :any)
    admin_policy = ApplicationPolicy.new(admin, :any)

    expect(viewer_policy.viewer?).to eq(true)
    expect(viewer_policy.operator?).to eq(false)
    expect(viewer_policy.admin?).to eq(false)

    expect(operator_policy.viewer?).to eq(true)
    expect(operator_policy.operator?).to eq(true)
    expect(operator_policy.admin?).to eq(false)

    expect(admin_policy.viewer?).to eq(true)
    expect(admin_policy.operator?).to eq(true)
    expect(admin_policy.admin?).to eq(true)
  end

  it "applies demo dataset policy permissions" do
    expect(Admin::Demo::DatasetPolicy.new(operator, :demo_dataset).create?).to eq(true)
    expect(Admin::Demo::DatasetPolicy.new(operator, :demo_dataset).preview?).to eq(true)
    expect(Admin::Demo::DatasetPolicy.new(viewer, :demo_dataset).create?).to eq(false)
    expect(Admin::Demo::DatasetPolicy.new(viewer, :demo_dataset).reset?).to eq(false)
  end

  it "applies fx rate policy permissions" do
    expect(FxRatePolicy.new(viewer, :fx_rate).history?).to eq(true)
    expect(FxRatePolicy.new(viewer, :fx_rate).template?).to eq(true)
    expect(FxRatePolicy.new(viewer, :fx_rate).upload?).to eq(false)

    expect(FxRatePolicy.new(operator, :fx_rate).upload?).to eq(true)
    expect(FxRatePolicy.new(operator, :fx_rate).ingest?).to eq(true)
    expect(FxRatePolicy.new(operator, :fx_rate).manage_rates?).to eq(true)
  end

  it "applies overview and system health policy permissions" do
    expect(OverviewPolicy.new(viewer, :overview).show?).to eq(true)
    expect(OverviewPolicy.new(viewer, :overview).ingestion_validation_errors_panel?).to eq(true)
    expect(SystemHealthPolicy.new(viewer, :system_health).show?).to eq(true)
    expect(SystemHealthPolicy.new(nil, :system_health).show?).to eq(false)
  end

  it "applies trade and run policy permissions" do
    expect(TradePolicy.new(admin, :trade).create?).to eq(true)
    expect(TradePolicy.new(operator, :trade).create?).to eq(false)
    expect(RunPolicy.new(operator, :run).execute?).to eq(true)
    expect(RunPolicy.new(viewer, :run).verify?).to eq(false)
  end
end
