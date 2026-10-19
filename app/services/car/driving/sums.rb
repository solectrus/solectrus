# The running sums of the daily values of a car over the dates of a ledger
# (see Car::Driving). The sum over a range is the difference of two running
# sums, so the window of each day of a long period costs no loop over its
# days.
#
# The keys are :distance (km), :energy_wh, :cost and :uncosted (the sessions
# without a cost).
class Car::Driving::Sums
  def initialize(ledger, car)
    @ledger = ledger
    @car = car
  end

  # The sum of a daily value over a range of the ledger
  def call(key, range)
    sums = running_sums[key]
    first = ledger.dates.begin
    sums[(range.end - first).to_i + 1] - sums[(range.begin - first).to_i]
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

  def add(running, value) = running << (running.last + value)
end
