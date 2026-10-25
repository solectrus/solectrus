# The save button of a form on the desktop, which the form-dirty controller
# enables once a field changes: a button with a check mark and its label, in
# a row of its own at the right edge. It shows only while it is enabled, as
# the save bar of a page form does (see Ui::SaveBar::Component). A phone has
# the save button in the title bar instead (see Ui::TitleBar::Component). The
# label is "Save" unless the form saves in another way.
#
# With a delete_path a delete button joins it: on the desktop a trash icon at
# the left edge, far from the save button, on a phone a red line of its own
# below the fields. It submits the same form as a DELETE to that path, so on
# a page it replaces the page in the history as a save does (see
# FormPageHelper).
class Ui::SubmitButton::Component < ViewComponent::Base
  # The attributes of every save button, here and in the title bar, the head
  # of a sheet and the save bar: disabled from the start, until the form-dirty
  # controller of the form finds a change. A button outside the form names it
  # by its id, `form`. The key carries dashes, so Slim writes it as Rails does.
  def self.save_attributes(form: nil)
    { form:, disabled: true, data: { 'form-dirty-submit': true } }.compact
  end

  # The primary Ui::Button::Component. While disabled, it keeps its place, so
  # the row does not move when it shows.
  SAVE_CLASS =
    'peer order-last justify-center transition duration-200 ' \
    'disabled:pointer-events-none disabled:invisible disabled:opacity-0'.freeze
  private_constant :SAVE_CLASS

  def initialize(label: nil, delete_path: nil)
    super()
    @label = label
    @delete_path = delete_path
  end

  attr_reader :delete_path

  def label
    @label || t('ui.save')
  end

  def delete_options
    { formaction: delete_path, formmethod: :delete, formnovalidate: true, 'aria-label': t('ui.delete') }
  end
end
