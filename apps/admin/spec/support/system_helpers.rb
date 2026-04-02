module SystemHelpers
  def wait_for_app_shell
    find(".app-shell", wait: 10)
  end

  def expand_sidebar
    wait_for_app_shell

    if page.has_css?(".app-shell.app-shell--sidebar-collapsed", wait: 2)
      find('button[data-action="sidebar#expand"]', visible: :all, wait: 10).click
    end

    expect(page).to have_no_css(".app-shell.app-shell--sidebar-collapsed", wait: 10)
  end

  def sidebar_nav_link(label_key)
    expand_sidebar
    find(".app-shell__nav--desktop", wait: 10)

    within(".app-shell__nav--desktop") do
      find("a.app-shell__nav-link", text: I18n.t(label_key), match: :first, wait: 10)
    end
  end

  def click_sidebar_nav(label_key)
    sidebar_nav_link(label_key).click
  end

  def wait_for_sidebar_panel(label_key)
    expand_sidebar
    find("section[aria-label=\"#{I18n.t(label_key)}\"]", wait: 10)
  end

  def within_sidebar_panel(label_key, &block)
    panel = wait_for_sidebar_panel(label_key)
    within(panel, &block)
  end

  def wait_for_financial_overview
    find('[data-controller="financial-overview"]', wait: 10)
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
