# The field of a picker in the timeframe select, with the picker in its
# details. It has two buttons apart: the period it shows, which a tap selects
# at once (see Timeframe::Select::Component), and a chevron, the summary of
# the details, which opens the picker for another one. A summary must not
# hold a button, so the period stands beside the details.
#
# A range has nothing to select at once. Without a `value`, the summary is all
# of the field and shows the period itself.
#
# The content is the text of the period, the `panel` the picker. `controller`
# is the picker whose targets the details, the summary and the text are. The
# text before the field, like "Month", carries the id `"#{id}-label"`. A
# summary cannot take a label, so the buttons name that text instead.
class Timeframe::Select::Field::Component < ViewComponent::Base
  renders_one :panel

  def initialize(controller:, id:, value:, selected:)
    super()
    @controller = controller
    @id = id
    @value = value
    @selected = selected
  end

  attr_reader :id, :value

  def choosable? = !value.nil?

  def target(name) = { "#{@controller}-target": name }

  def details_data = { **target('details'), action: "toggle->#{@controller}#handleToggle" }

  def text_id = "#{id}-text"

  # The period names its field too. The chevron of a field with a period
  # beside it names the field alone, the summary of a range its period too.
  def labelled_by(with_text: true) = ["#{id}-label", (text_id if with_text)].compact.join(' ')

  def summary_classes
    return [CHEVRON_CLASSES, chevron_colors, 'h-full list-none'] if choosable?

    [*button_classes, 'flex items-center justify-between gap-2 list-none']
  end

  def period_data = { action: 'timeframe--select--component#choose', 'timeframe--select--component-value-param': value }

  # The period, marked when the page shows it. On a phone, the field is a
  # tile of half the width, so the period and its chevron join as one split
  # button, 48px high, a bit more than a tap target.
  def button_classes
    [
      'flex-1 min-w-0 px-3 py-2 max-lg:py-3 rounded-lg text-left text-sm max-lg:text-subhead max-lg:leading-6 cursor-pointer transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
      'max-[22.5rem]:px-2.5 lg:landscape:px-4 lg:landscape:text-base',
      ('rounded-r-none lg:landscape:rounded-r-lg' if choosable?),
      @selected ? Timeframe::Select::Component::SELECTED_COLORS : Timeframe::Select::Component::UNSELECTED_COLORS,
    ]
  end

  # The chevron of the marked period takes a light tint of its color, so the
  # split button reads as one
  def chevron_colors
    if @selected
      'bg-indigo-100 text-indigo-600 hover:bg-indigo-200 dark:bg-indigo-600/40 dark:text-indigo-100 dark:hover:bg-indigo-600/60'
    else
      'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-300 hover:bg-indigo-100 dark:hover:bg-indigo-900'
    end
  end

  CHEVRON_CLASSES =
    'flex w-10 items-center justify-center rounded-lg rounded-l-none ' \
    'max-[22.5rem]:w-8 lg:landscape:w-12 lg:landscape:rounded-l-lg ' \
    'cursor-pointer transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500'.freeze
  private_constant :CHEVRON_CLASSES
end
