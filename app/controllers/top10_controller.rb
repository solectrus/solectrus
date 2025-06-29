class Top10Controller < ApplicationController
  include ParamsHandling
  include SummaryChecker

  def index
    redirect_to(default_path) unless period && sensor && calc && sort
    redirect_to(default_path(calc: 'sum')) if calc == 'max' && !supports_max?

    load_missing_or_stale_summary_days(Timeframe.all)
  end

  private

  helper_method def timeframe
    @timeframe ||= Timeframe.new(period || 'all')
  end

  helper_method def title
    t('layout.top10')
  end

  def default_path(override = {})
    top10_path(
      {
        period: period || 'day',
        sensor: sensor || 'inverter_power',
        calc: calc || 'sum',
        sort: sort || 'desc',
      }.merge(override),
    )
  end

  helper_method def supports_max?
    # Custom sensors are not supported for max calculation
    !sensor.in?(SensorConfig::CUSTOM_SENSORS)
  end

  helper_method def nav_items
    [
      {
        name: t('calculator.day'),
        href: path_with_period('day'),
        current: period == 'day',
      },
      {
        name: t('calculator.week'),
        href: path_with_period('week'),
        current: period == 'week',
      },
      {
        name: t('calculator.month'),
        href: path_with_period('month'),
        current: period == 'month',
      },
      {
        name: t('calculator.year'),
        href: path_with_period('year'),
        current: period == 'year',
      },
    ]
  end

  def path_with_period(period)
    url_for(permitted_params.merge(period:, only_path: true))
  end
end
