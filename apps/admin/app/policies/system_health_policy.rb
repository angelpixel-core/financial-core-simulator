class SystemHealthPolicy < ApplicationPolicy
  def show?
    viewer?
  end

  def pnl_trend?
    viewer?
  end
end
