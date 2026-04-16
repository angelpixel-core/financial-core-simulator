require "rails_helper"

RSpec.describe Admin::AccessControl::Roles::Repository do
  subject(:repository) { described_class.new }

  it "creates default roles with expected levels" do
    repository.ensure_defaults!

    expect(repository.level_for("viewer")).to eq(0)
    expect(repository.level_for("operator")).to eq(1)
    expect(repository.level_for("admin")).to eq(2)
  end
end
