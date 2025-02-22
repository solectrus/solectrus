class Timeframe # rubocop:disable Metrics/ClassLength
  include ActionView::Helpers::DateHelper

  def self.regex
    /(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|now|day|week|month|year|all/
  end

  # Shortcut methods
  %i[now all day week month year].each do |method|
    define_singleton_method method do
      new(method.to_s)
    end
  end

  def initialize(
    string,
    min_date: Rails.application.config.x.installation_date,
    allowed_days_in_future: 6
  )
    unless string.respond_to?(:match?) && string.match?(self.class.regex)
      raise ArgumentError, "'#{string}' is not a valid timeframe"
    end

    @original_string = string

    @string =
      case string
      when 'day'
        Date.current.strftime('%Y-%m-%d')
      when 'week'
        Date.current.strftime('%G-W%V')
      when 'month'
        Date.current.strftime('%Y-%m')
      when 'year'
        Date.current.strftime('%Y')
      else
        string
      end

    @min_date = min_date
    @allowed_days_in_future = allowed_days_in_future
  end

  attr_reader :string, :min_date, :allowed_days_in_future

  delegate :to_s, to: :@original_string

  def out_of_range?
    return true if min_date && ending.to_date < min_date
    return true if max_date && beginning.to_date > max_date

    false
  end

  def current?
    case id
    when :now, :all
      true
    when :day
      date.today?
    when :week
      date.cweek == Date.current.cweek
    when :month
      date.month == Date.current.month
    when :year
      date.year == Date.current.year
    end
  end

  def starts_today?
    current? && effective_beginning_date.today?
  end

  def today?
    day? && current?
  end

  def past?
    return false if now? || all?

    ending.to_date < Date.current
  end

  def future?
    return false if now? || all?

    beginning.to_date > Date.current
  end

  # Number of days that have passed since the beginning of the timeframe
  def days_passed
    return 0 if now? || today? || beginning.nil?

    if past?
      (ending.to_date - effective_beginning_date + 1)
    elsif beginning.past?
      (Date.current - effective_beginning_date)
    else
      0
    end
  end

  def can_paginate?
    id.in?(%i[day week month year])
  end

  def id
    @id ||=
      case string
      when /\d{4}-\d{2}-\d{2}/
        :day
      when /\d{4}-W\d{2}/
        :week
      when /\d{4}-\d{2}/
        :month
      when /\d{4}/
        :year
      when 'all', 'now'
        string.to_sym
      end
  end

  def now?
    id == :now
  end

  def day?
    id == :day
  end

  def short?
    now? || day?
  end

  def week?
    id == :week
  end

  def month?
    id == :month
  end

  def year?
    id == :year
  end

  def all?
    id == :all
  end

  def localized
    case id
    when :now
      I18n.l date, format:
    when :day
      I18n.l(date, format: :long)
    when :week
      I18n.l(date, format: :week)
    when :month
      I18n.l(date, format: :month)
    when :year
      date.year.to_s
    when :all
      I18n.t(
        'timeframe.all',
        since:
          distance_of_time_in_words_to_now(
            min_date,
            only: :years,
            scope: 'datetime.distance_in_words.dativ',
          ),
      )
    end
  end

  def beginning # rubocop:disable Metrics/CyclomaticComplexity
    case id
    when :now
      Time.current
    when :day
      date.beginning_of_day
    when :week
      date.beginning_of_week.beginning_of_day
    when :month
      date.beginning_of_month.beginning_of_day
    when :year
      date.beginning_of_year.beginning_of_day
    when :all
      min_date&.beginning_of_year&.beginning_of_day
    end
  end

  # Date of the beginning, but not before min_date
  def effective_beginning_date
    [beginning.to_date, min_date].compact.max
  end

  # Date of the ending, but not after max_date or today
  def effective_ending_date
    [ending.to_date, max_date].compact.min
  end

  def ending
    case id
    when :now
      Time.current
    when :day
      date.end_of_day
    when :week
      date.end_of_week.end_of_day
    when :month
      date.end_of_month.end_of_day
    when :year
      date.end_of_year.end_of_day
    when :all
      [max_date, Date.current].compact.min.end_of_day
    end
  end

  def beginning_of_next
    return ending if id == :now

    case id
    when :day
      date.tomorrow.beginning_of_day
    when :week
      date.end_of_week.tomorrow.beginning_of_day
    when :month
      date.end_of_month.tomorrow.beginning_of_day
    when :year
      date.end_of_year.tomorrow.beginning_of_day
    when :all
      [max_date, Date.current].compact.min.tomorrow.beginning_of_day
    end
  end

  def next(force: false)
    date = next_date(force:)
    return unless date

    self.class.new date.strftime(format), min_date:, allowed_days_in_future:
  end

  def prev
    date = prev_date
    return unless date

    self.class.new prev_date.strftime(format),
                   min_date:,
                   allowed_days_in_future:
  end

  def next_date(force: false)
    return if id.in?(%i[now all])

    change(+1, force:)
  end

  def prev_date
    return if id.in?(%i[now all])

    change(-1)
  end

  def corresponding_day
    effective_ending_date.strftime(format(target_id: :day))
  end

  def corresponding_week
    effective_ending_date.strftime(format(target_id: :week))
  end

  def corresponding_month
    effective_ending_date.strftime(format(target_id: :month))
  end

  def corresponding_year
    effective_ending_date.strftime(format(target_id: :year))
  end

  def date
    case id
    when :now
      Time.current
    when :day, :week
      Date.parse(string)
    when :month
      Date.parse("#{string}-01")
    when :year
      Date.parse("#{string}-01-01")
    end
  end

  private

  def change(amount, force: false)
    new_date = raw_change(amount)

    unless force
      return if new_date < min_date
      return if new_date > max_date
    end

    new_date
  end

  def raw_change(amount)
    case id
    when :day
      change_day(amount)
    when :week
      change_week(amount)
    when :month
      change_month(amount)
    when :year
      change_year(amount)
    end
  end

  def change_day(amount)
    raise RuntimeError unless day?

    date + amount.day
  end

  def change_week(amount)
    raise RuntimeError unless week?

    result = date + amount.week
    amount.positive? ? result.beginning_of_week : result.end_of_week
  end

  def change_month(amount)
    raise RuntimeError unless month?

    result = date + amount.month
    amount.positive? ? result.beginning_of_month : result.end_of_month
  end

  def change_year(amount)
    raise RuntimeError unless year?

    result = date + amount.year
    amount.positive? ? result.beginning_of_year : result.end_of_year
  end

  def max_date
    day? ? (Date.current + allowed_days_in_future.days) : Date.current
  end

  FORMAT = {
    now: :now,
    day: '%Y-%m-%d',
    week: '%G-W%V',
    month: '%Y-%m',
    year: '%Y',
  }.freeze

  private_constant :FORMAT

  def format(target_id: id)
    FORMAT[target_id]
  end
end
