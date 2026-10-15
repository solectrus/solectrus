# The save buttons of a page form on the desktop, like the general settings,
# at the right of the tabs of the header. They show only while the form has
# changes: a button that discards them and the save button. A phone has the
# save button in the title bar instead (see Ui::TitleBar::Component), so the
# bar hides itself below lg.
#
# It stands outside the form and names it by its id, `form`. The form-dirty
# controller of the form enables the save button once a field changes, and
# the bar shows while the button is enabled. The discard button resets the
# form to the values of the page.
#
#   = render Ui::SaveBar::Component.new(form: 'settings_general_form')
class Ui::SaveBar::Component < ViewComponent::Base
  # The container of the tabs and the bar. While the form has changes, it
  # dims the other tabs and takes their clicks, so a tab does not leave the
  # changes behind.
  TABS_CLASS =
    '[&:has([data-form-dirty-submit]:enabled)_nav_a:not([aria-current])]:opacity-40 ' \
    '[&:has([data-form-dirty-submit]:enabled)_nav_a:not([aria-current])]:pointer-events-none'.freeze
  public_constant :TABS_CLASS

  def initialize(form:)
    super()
    @form = form
  end

  attr_reader :form
end
