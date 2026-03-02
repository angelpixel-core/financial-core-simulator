class Admin::Dashboard::TopAccountsTableComponent < ViewComponent::Base
  def initialize(accounts:)
    @accounts = accounts
  end
end
