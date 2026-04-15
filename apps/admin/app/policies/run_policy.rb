class RunPolicy < ApplicationPolicy
  def show?
    viewer?
  end

  def execute?
    operator?
  end

  def verify?
    operator?
  end
end
