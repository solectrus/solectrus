# The save button of a form, which the form-dirty controller enables once a
# field changes. On the desktop a button with a check mark and its label, in a
# row of its own at the right edge. On a phone a capsule as wide as the page,
# as the buttons of iOS. The label is "Save" unless the form saves in another
# way.
#
# With a delete_path a delete button joins it: on the desktop a trash icon at
# the left edge, far from the save button, on a phone wide and red below it.
# It submits the same form as a DELETE to that path, so on a page it replaces
# the page in the history as a save does (see FormPageHelper).
#
# An entry that leaves the list in another way, like a proposal that is
# dismissed, gives that button its own method, label, question before the
# submit and icon: removal: { method:, label:, confirm:, icon: }.
class Ui::SubmitButton::Component < ViewComponent::Base
  # A wide capsule on a phone, the primary button of Button::Component on the
  # desktop
  BUTTON_CLASS =
    'inline-flex items-center justify-center gap-2 click-animation transition text-white bg-indigo-600 ' \
    'focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:focus:ring-offset-slate-900 ' \
    'disabled:pointer-events-none ' \
    'max-lg:w-full max-lg:rounded-full max-lg:py-3.5 max-lg:text-headline max-lg:font-semibold ' \
    'max-lg:active:bg-indigo-700 max-lg:dark:bg-indigo-700 ' \
    'max-lg:disabled:bg-gray-200 max-lg:disabled:text-gray-400 ' \
    'max-lg:dark:disabled:bg-slate-800 max-lg:dark:disabled:text-slate-500 ' \
    'lg:rounded lg:px-3 lg:py-2 lg:shadow-sm lg:hover:bg-indigo-700 lg:hover:scale-105 ' \
    'lg:dark:bg-indigo-800 lg:dark:text-gray-300 ' \
    'lg:disabled:shadow-none lg:disabled:bg-gray-200 lg:disabled:text-gray-400 ' \
    'lg:dark:disabled:bg-slate-700 lg:dark:disabled:text-slate-400'.freeze
  private_constant :BUTTON_CLASS

  def initialize(label: nil, delete_path: nil, removal: {})
    super()
    @label = label
    @delete_path = delete_path
    @removal_options = removal
  end

  attr_reader :delete_path

  def label
    @label || t('crud.save')
  end

  def removal
    @removal ||= { method: :delete, label: t('crud.delete'), confirm: t('crud.confirm_delete'), icon: 'trash' }.merge(@removal_options)
  end

  def delete_options
    { formaction: delete_path, formmethod: removal[:method], formnovalidate: true, 'aria-label': removal[:label] }
  end
end
