class Timeframe::Select::Component < ViewComponent::Base
  # The name of a field: a caption above it on a phone, as the headings of
  # the groups below, and a label before it on a wide screen
  LABEL_CLASSES =
    'text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400 ' \
    'lg:landscape:text-sm lg:landscape:normal-case lg:landscape:tracking-normal lg:landscape:font-medium ' \
    'lg:landscape:text-gray-700 dark:lg:landscape:text-gray-300'.freeze

  # A field with its name, as a tile on a phone (see the template)
  TILE_CLASSES = 'flex flex-col gap-1 min-w-0 lg:landscape:contents'.freeze

  # Shared CSS classes for form elements
  INPUT_CLASSES = 'w-full px-4 py-2.5 text-base border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 appearance-none cursor-pointer transition-colors hover:border-gray-400 dark:hover:border-gray-500'.freeze
  BACK_BUTTON_CLASSES = 'absolute left-4 top-1/2 -translate-y-1/2 flex items-center gap-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-gray-400 cursor-pointer transition-colors uppercase text-xs tracking-wider'.freeze

  # The colors of a button of the select, with its period selected or not
  SELECTED_COLORS = 'bg-indigo-600 text-white hover:bg-indigo-700'.freeze
  UNSELECTED_COLORS = 'bg-gray-100 text-gray-900 dark:bg-gray-700 dark:text-white hover:bg-indigo-100 dark:hover:bg-indigo-900'.freeze

  public_constant :LABEL_CLASSES, :TILE_CLASSES, :INPUT_CLASSES, :BACK_BUTTON_CLASSES, :SELECTED_COLORS, :UNSELECTED_COLORS

  # The kinds of timeframes that the select can offer: a picker for a day, a
  # week, a month, a year or a range, and a group of the relative picker (see
  # Timeframe::Select::RelativePicker::Component)
  KINDS = %i[day week month year range hours days months all].freeze
  public_constant :KINDS

  # `page` gives the address of the selected timeframe and tells which kinds
  # and whether the forecast the page offers (see TimeframePage::Sensor).
  # `comparisons` are the links to the comparisons of the years, if any.
  # `forecast` says that the select belongs to the forecast, which none of
  # the fields can mark.
  def initialize(timeframe:, page:, comparisons: nil, forecast: false)
    super()
    @timeframe = timeframe
    @page = page
    @comparisons = comparisons
    @forecast = forecast
  end

  attr_reader :timeframe, :comparisons

  # The forecast, after the fields, as the arrow of today leads to it
  def forecast_items
    return [] unless @page.forecast?

    [{ name: t('.next_days'), href: helpers.forecast_path, current: @forecast }]
  end

  # The forecast looks like the period of a field
  def forecast_classes(item)
    [
      'flex items-center px-3 py-2 max-lg:py-3 rounded-lg text-sm max-lg:text-subhead max-lg:leading-6 cursor-pointer transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
      item[:current] ? SELECTED_COLORS : UNSELECTED_COLORS,
    ]
  end

  delegate :url_template, :offers?, to: :@page

  # The groups of the relative picker that the page offers
  def relative_groups = Timeframe::Select::RelativePicker::Component::GROUPS.select { offers?(it) }

  def min_date
    Rails.application.config.x.installation_date
  end
end
