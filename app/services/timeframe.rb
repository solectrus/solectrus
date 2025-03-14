class Timeframe # rubocop:disable Metrics/ClassLength
  include ActionView::Helpers::DateHelper

  REGEX_DAY = /\d{4}-\d{2}-\d{2}/
  REGEX_DAYS = /P\d{1,3}D/
  REGEX_WEEK = /\d{4}-W\d{2}/
  REGEX_MONTH = /\d{4}-\d{2}/
  REGEX_MONTHS = /P\d{1,2}M/
  REGEX_YEAR = /\d{4}/
  REGEX_YEARS = /P\d{1,2}Y/
  REGEX_KEYWORD = /now|day|week|month|year|all/

  REGEX =
    /#{[REGEX_DAY, REGEX_DAYS, REGEX_WEEK, REGEX_MONTH, REGEX_MONTHS, REGEX_YEAR, REGEX_YEARS, REGEX_KEYWORD].map(&:source).join('|')}/

  private_constant :REGEX_DAY
  private_constant :REGEX_DAYS
  private_constant :REGEX_WEEK
  private_constant :REGEX_MONTH
  private_constant :REGEX_MONTHS
  private_constant :REGEX_YEAR
  private_constant :REGEX_YEARS
  private_constant :REGEX_KEYWORD
  public_constant :REGEX

  # Shortcut methods
  REGEX_KEYWORD
    .source
    .split('|')
    .each do |method|
      define_singleton_method method do
        new(method)
      end
    end

  def initialize(
    string,
    min_date: Rails.application.config.x.installation_date,
    allowed_days_in_future: 6
  )
    unless string.respond_to?(:match?) && string.match?(REGEX)
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
    when :now, :all, :days, :months, :years
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

  def relative?
    days? || months? || years?
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

  def id # rubocop:disable Metrics/CyclomaticComplexity
    @id ||=
      case string
      when REGEX_DAY
        :day
      when REGEX_DAYS
        :days
      when REGEX_WEEK
        :week
      when REGEX_MONTH
        :month
      when REGEX_MONTHS
        :months
      when REGEX_YEAR
        :year
      when REGEX_YEARS
        :years
      when REGEX_KEYWORD
        string.to_sym
      end
  end

  def now?
    id == :now
  end

  def day?
    id == :day
  end

  def days?
    id == :days
  end

  def short?
    now? || day?
  end

  def week?
    id == :week
  end

  def week_like?
    week? || (days? && relative_count == 7 && current?)
  end

  def month?
    id == :month
  end

  def month_like?
    month? || (days? && relative_count == 30 && current?)
  end

  def months?
    id == :months
  end

  def year?
    id == :year
  end

  def year_like?
    year? || (months? && relative_count == 12 && current?)
  end

  def years?
    id == :years
  end

  def all?
    id == :all
  end

  def relative_count
    return unless relative?

    string[/\d+/].to_i
  end

  def iso8601
    to_s
  end

  def localized # rubocop:disable Metrics/CyclomaticComplexity
    case id
    when :now
      I18n.l(date, format:)
    when :day
      I18n.l(date, format: :long)
    when :days
      I18n.t('timeframe.days', count: relative_count)
    when :week
      I18n.l(date, format: :week)
    when :month
      I18n.l(date, format: :month)
    when :months
      I18n.t('timeframe.months', count: relative_count)
    when :year
      date.year.to_s
    when :years
      I18n.t('timeframe.years', count: relative_count)
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
    when :days
      (relative_count - 1).days.ago.beginning_of_day
    when :week
      date.beginning_of_week.beginning_of_day
    when :month
      date.beginning_of_month.beginning_of_day
    when :months
      (relative_count - 1).month.ago.beginning_of_month.beginning_of_day
    when :year
      date.beginning_of_year.beginning_of_day
    when :years
      (relative_count - 1).year.ago.beginning_of_year.beginning_of_day
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
    when :day, :days, :months, :years
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
    case id
    when :now
      ending
    when :day, :days
      date.tomorrow.beginning_of_day
    when :week
      date.end_of_week.tomorrow.beginning_of_day
    when :month, :months
      date.end_of_month.tomorrow.beginning_of_day
    when :year, :years
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
    return if id.in?(%i[now all days months years])

    change(+1, force:)
  end

  def prev_date
    return if id.in?(%i[now all days months years])

    change(-1)
  end

  def corresponding_day
    effective_ending_date.strftime(format(target_id: :day))
  end

  def corresponding_week
    if week? && current?
      'P7D'
    else
      effective_ending_date.strftime(format(target_id: :week))
    end
  end

  def corresponding_month
    if month? && current?
      'P30D'
    else
      effective_ending_date.strftime(format(target_id: :month))
    end
  end

  def corresponding_year
    if year? && current?
      'P12M'
    else
      effective_ending_date.strftime(format(target_id: :year))
    end
  end

  def date
    case id
    when :now
      Time.current
    when :day, :week
      Date.parse(string)
    when :days, :months, :years
      Date.current
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
