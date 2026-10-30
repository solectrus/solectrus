# The gaps of the comparison with a combustion car above its figures (see
# Car::ComparisonGaps): each one with a warning, and for the admin with a
# link to the place that fills it. Without a gap, nothing shows.
class Car::ComparisonWarnings::Component < ViewComponent::Base
  Warning = Data.define(:text, :href, :link)
  public_constant :Warning

  def initialize(gaps:, timeframe:)
    super()
    @gaps = gaps
    @timeframe = timeframe
  end

  def render? = @gaps.any?

  def warnings
    @gaps.map do |gap|
      href = (path(gap) if helpers.admin?)
      Warning.new(text: text(gap), href:, link: (t(".links.#{gap.key}") if href))
    end
  end

  private

  def text(gap)
    case gap.key
    when :proposals then t('.proposals', count: gap.value)
    when :unrated then t('.unrated', distance: Sensor::ValueFormatter.new(gap.value, unit: :kilometer).to_s)
    else t(".#{gap.key}")
    end
  end

  # The place that fills a gap, nil without one. The tax is a setting of
  # one car, so several cars without a tax have no link.
  def path(gap)
    case gap.key
    when :proposals then helpers.cars_charging_sessions_path(kind: 'offsite', car: nil, timeframe: @timeframe.to_param, review: '1')
    when :payments then helpers.settings_car_payments_path
    when :tax then (helpers.edit_settings_car_path(gap.value.sole) if gap.value.one?)
    end
  end
end
