# The way to the trends of a home page, beside its timeframe: in the bar of
# a wide screen (Timeframe::Component) and in the row of the period of a
# phone (Timeframe::Pager::Component). It opens the trend overview of the
# page (TrendOverview), or without its permission a teaser in its place
# (see SensorPathHelper#page_trends_path).
class Timeframe::TrendsButton::Component < ViewComponent::Base
  # In the bar of a wide screen a square with slightly rounded corners, with
  # the colors and the ring of the select of the car beside it (see
  # Ui::Dropdown::Component), like Ui::AddButton::Component. On a phone the
  # icon alone, in the muted color of the arrows beside it, so it stays quiet
  # beside the name. Its round area keeps a tap easy.
  CLASSES = {
    bar: [
      'flex size-9 items-center justify-center rounded-md',
      'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400',
      Ui::Dropdown::Component.button_class(:header),
    ].join(' ').freeze,
    pager: 'flex size-9 shrink-0 items-center justify-center rounded-full click-animation focus-ring',
  }.freeze
  private_constant :CLASSES

  def initialize(timeframe:, variant:)
    super()
    @timeframe = timeframe
    @variant = variant
  end

  attr_reader :timeframe, :variant

  def render?
    href.present?
  end

  def call
    link_to icon('arrow-trend-up', class: 'fa-lg'),
            href,
            class: CLASSES[variant],
            title: label,
            'aria-label': label,
            data: Ui::TurboModal::Component.link_data(tooltip: variant == :bar, trends_button: true)
  end

  private

  def href
    return @href if defined?(@href)

    @href = helpers.page_trends_path(timeframe:)
  end

  def label = t('.trends')
end
