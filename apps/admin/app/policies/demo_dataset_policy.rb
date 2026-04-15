class DemoDatasetPolicy < ApplicationPolicy
  def create?
    operator?
  end

  def preview?
    operator?
  end

  def reset?
    operator?
  end
end
