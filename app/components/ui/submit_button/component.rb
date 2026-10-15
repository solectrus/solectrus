# The save button of a form on the desktop, which the form-dirty controller
# enables once a field changes: a button with a check mark and its label, in
# a row of its own at the right edge. A phone has the save button in the
# title bar instead (see Ui::TitleBar::Component). The label
# is "Save" unless the form saves in another way.
#
# With a delete_path a delete button joins it: on the desktop a trash icon at
# the left edge, far from the save button, on a phone a red line of its own
# below the fields. It submits the same form as a DELETE to that path, so on
# a page it replaces the page in the history as a save does (see
# FormPageHelper).
class Ui::SubmitButton::Component < ViewComponent::Base
  # The primary button of Button::Component
  BUTTON_CLASS =
    'inline-flex items-center justify-center gap-2 click-animation transition text-white bg-indigo-600 ' \
    'focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-slate-900 ' \
    'disabled:pointer-events-none ' \
    'rounded px-3 py-2 shadow-sm hover:bg-indigo-700 hover:scale-105 ' \
    'dark:bg-indigo-800 dark:text-gray-300 ' \
    'disabled:shadow-none disabled:bg-gray-200 disabled:text-gray-400 ' \
    'dark:disabled:bg-slate-700 dark:disabled:text-slate-400'.freeze
  private_constant :BUTTON_CLASS

  def initialize(label: nil, delete_path: nil)
    super()
    @label = label
    @delete_path = delete_path
  end

  attr_reader :delete_path

  def label
    @label || t('crud.save')
  end

  def delete_options
    { formaction: delete_path, formmethod: :delete, formnovalidate: true, 'aria-label': t('crud.delete') }
  end
end
