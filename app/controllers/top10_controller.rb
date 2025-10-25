class Top10Controller < ApplicationController
  include ParamsHandling
  include SummaryChecker

  def index
    return redirect_to(default_path) unless period && sensor_name && calc && sort
    return redirect_to(default_path(calc: 'sum')) if calc == 'max' && !supports_max?
    return redirect_to(default_path(calc: default_calc)) unless supports_calc?

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
        sensor_name: sensor_name || :inverter_power,
        calc: calc || 'sum',
        sort: sort || 'desc',
      }.merge(override),
    )
  end

  helper_method def supports_max?
    return false unless sensor

    sensor.allowed_aggregations.include?(:max)
  end

  def supports_calc?
    return false unless sensor
    return true unless calc

    sensor.allowed_aggregations.include?(calc.to_sym)
  end

  def default_calc
    return 'sum' unless sensor

    # Use first allowed aggregation as default
    sensor.allowed_aggregations.first.to_s
  end

  helper_method def nav_items
    [
      {
        name: t('data.day'),
        href: path_with_period('day'),
        current: period == 'day',
      },
      {
        name: t('data.week'),
        href: path_with_period('week'),
        current: period == 'week',
      },
      {
        name: t('data.month'),
        href: path_with_period('month'),
        current: period == 'month',
      },
      {
        name: t('data.year'),
        href: path_with_period('year'),
        current: period == 'year',
      },
    ]
  end

  def path_with_period(period)
    url_for(permitted_params.merge(period:, only_path: true))
  end
end
