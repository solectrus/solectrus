# The time axis of the timeline of a day (see Car::DayTimeline::Component):
# the place of a time in percent of the day, the clock of a time, and the
# labels below the rows. The axis is the local day, so a day of a change of
# the clock has 23 or 25 hours on the same width.
#
# One time stands for now during the whole render, so the line of now and the
# labels agree.
class Car::DayTimeline::Axis
  # A label of the axis, with its place in percent of the day. A label near
  # now gives way to the label of now: on the desktop within MIN_DISTANCE, on a
  # phone with its wider labels within twice that. A `major` label, every six
  # hours, also shows on a phone.
  Tick = Data.define(:label, :position, :major, :desktop, :phone)
  public_constant :Tick

  MIN_DISTANCE = 90.minutes
  private_constant :MIN_DISTANCE

  # The start and the end of the day stay the same, so a render that places
  # some hundred times builds them once
  def initialize(timeframe, now: Time.current)
    @timeframe = timeframe
    @current = now
    @beginning = timeframe.beginning
    @ending = timeframe.beginning_of_next
  end

  # The place of a time in percent of the day
  def position(time)
    ((time - beginning) * 100.0 / (ending - beginning)).clamp(0, 100).round(3)
  end

  # The place of now on the running day, nil on a past day
  def now = (position(@current) if @timeframe.today?)

  # A time of the day in the time zone of the page. The end of the day is
  # 24:00, and not 00:00 of the next day.
  def clock(time) = time >= ending ? '24:00' : time.in_time_zone.strftime('%H:%M')

  # From one time to another, with a narrow space beside the dash that does
  # not break the line
  def range(from, to) = "#{clock(from)}\u202F–\u202F#{clock(to)}"

  # A label every three hours, on a phone every six
  def ticks
    (0..24).step(3).map do |hour|
      time = hour == 24 ? ending : beginning.change(hour:)
      distance = (time - @current).abs if @timeframe.today?
      major = (hour % 6).zero?
      Tick.new(
        label: format('%02d:00', hour),
        position: position(time),
        major:,
        desktop: distance.nil? || distance > MIN_DISTANCE,
        phone: major && (distance.nil? || distance > MIN_DISTANCE * 2),
      )
    end
  end

  private

  attr_reader :beginning, :ending
end
