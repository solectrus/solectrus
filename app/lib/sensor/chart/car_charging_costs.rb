# The charging cost of now and a day on the car page: the cost of the wallbox
# without the sessions that count for no selection, like the charging power
# (see Sensor::Chart::CarChargingPower). A longer timeframe has the columns of
# the sessions (see Sensor::Chart::CarSessions).
#
# A day stacks the cost of the offsite sessions of the selected cars on the
# wallbox. The profile of the charging power tells when a session charged,
# and its price, the cost per kWh, gives the cost of each part.
class Sensor::Chart::CarChargingCosts < Sensor::Chart::WallboxCosts
  include Sensor::Chart::Concerns::WithoutOtherSessions
  include Sensor::Chart::Concerns::OffsiteSessions
  include Sensor::Chart::Concerns::BlankWithoutPositive

  def blank_message = I18n.t('data.car_no_charging')

  def blank_icon = 'plug'

  private

  def datasets(chart_data_items)
    parts = super(chart_data_items.map { without_other_sessions(it) })
    return parts if offsite_sessions.none?

    [*parts, offsite_dataset(chart_data_items.first[:labels])]
  end

  # Straight edges, so the area of a session is a rectangle
  def offsite_dataset(labels)
    costs = per_hour(offsite_sums(labels) { |session, energy| energy * price_per_wh(session) })

    build_dataset(cost_grid_sensor, data: costs.map { it.round(4) }).merge(
      id: 'offsite',
      label: ChargingSession.human_enum_name(:kind, :offsite),
      colorClass: Car::ChargingSource[:offsite].color_class,
      stack: stack_id,
      summed: true,
      noGradient: true,
      fill: '-1',
      tension: 0,
      cubicInterpolationMode: 'default',
    )
  end

  # A session without a cost costs nothing
  def price_per_wh(session)
    return 0 unless session.cost && session.kwh.to_f.positive?

    session.cost.to_f / session.kwh / 1000
  end
end
