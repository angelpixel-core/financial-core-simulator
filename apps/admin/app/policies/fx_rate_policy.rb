class FxRatePolicy < ApplicationPolicy
  def history?
    viewer?
  end

  def observability?
    viewer?
  end

  def template?
    viewer?
  end

  def upload?
    operator?
  end

  def ingest?
    operator?
  end

  def manage_rates?
    operator?
  end

  def update_reporting?
    operator?
  end
end
