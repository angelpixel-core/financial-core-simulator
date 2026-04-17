class OverviewPolicy < ApplicationPolicy
  def show?
    viewer?
  end

  def top_accounts?
    viewer?
  end

  def runs_trend?
    viewer?
  end

  def status_mix?
    viewer?
  end

  def ingestion_validation_errors_panel?
    viewer?
  end

  def export_financial_overview?
    viewer?
  end
end
