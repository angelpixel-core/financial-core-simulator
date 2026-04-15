class TradePolicy < ApplicationPolicy
  def index?
    viewer?
  end

  def create?
    admin?
  end
end
