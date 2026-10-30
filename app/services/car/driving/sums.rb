# The running sums of the daily values of a car over the dates of a ledger
# (see Car::Driving). The sum over a range is the difference of two running
# sums, so the window of each day of a long period costs no loop over its
# days.
#
# The keys are :distance (km), :energy_wh, :cost and :uncosted (the sessions
# without a cost), and [source, :kwh or :cost] for each source of
# Car::EnergySources. Only the comparison asks for the sources, so they have
# running sums of their own.
class Car::Driving::Sums
  def initialize(ledger, car)
    @ledger = ledger
    @car = car
  end

  # The sum of a daily value over a range of the ledger. The Julian day
  # numbers give the index, because the difference of two dates is a
  # Rational, and the windows ask for many sums.
  def call(key, range)
    sums = key.is_a?(Array) ? source_sums[key] : running_sums[key]
    first = ledger.dates.begin.jd
    sums[range.end.jd - first + 1] - sums[range.begin.jd - first]
  end

  private

  attr_reader :ledger, :car

  # { key => [0, day 1, day 1 + day 2, ...] }
  def running_sums
    @running_sums ||=
      begin
        sums = { distance: [0.0], energy_wh: [0.0], cost: [0.0], uncosted: [0] }
        ledger.dates.each do |date|
          sessions = ledger.daily_sessions(car, date)
          add(sums[:distance], ledger.daily_distance(car, date))
          add(sums[:energy_wh], sessions.kwh * 1000.0)
          add(sums[:cost], sessions.cost)
          add(sums[:uncosted], sessions.uncosted)
        end
        sums
      end
  end

  # { [source, :kwh or :cost] => [0, day 1, ...] }
  def source_sums
    @source_sums ||=
      begin
        sums = Car::EnergySources.members.product(%i[kwh cost]).index_with { [0.0] }
        ledger.dates.each do |date|
          ledger.daily_sources(car, date).each do |source, (kwh, cost)|
            add(sums[[source, :kwh]], kwh)
            add(sums[[source, :cost]], cost)
          end
        end
        sums
      end
  end

  def add(running, value) = running << (running.last + value)
end
