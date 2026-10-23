# The note that no car is in use, in the live view and in a period, as a
# Ui::EmptyState. The admin gets a link to the settings of the cars, where the
# period of use of each car lives.
class Car::NoneInUse::Component < ViewComponent::Base
  def initialize(text:)
    super()
    @text = text
  end

  attr_reader :text

  LINK_CLASS =
    'inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-sm font-medium ' \
    'bg-indigo-50 text-indigo-700 hover:bg-indigo-100 ' \
    'dark:bg-indigo-950/60 dark:text-indigo-300 dark:hover:bg-indigo-900/60 ' \
    'transition-colors click-animation'.freeze
  private_constant :LINK_CLASS

  def edit_link
    return unless helpers.admin?

    link_to helpers.settings_cars_path, class: LINK_CLASS, data: { turbo_frame: '_top' } do
      safe_join([helpers.icon('pencil', class: 'text-xs'), t('data.car_edit_periods')])
    end
  end
end
