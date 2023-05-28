class Timeframe # rubocop:disable Metrics/ClassLength
  def self.regex
    /(\d{4}((-W\d{2})|(-\d{2}))?(-\d{2})?)|all|now/
  end

  def self.now
    new('now')
  end

  def self.all
    new('all')
  end

  def initialize(string, min_date: nil, allowed_days_in_future: nil)
    unless string.respond_to?(:match?) && string.match?(self.class.regex)
      raise ArgumentError, "'#{string}' is not a valid timeframe"
    end

    @string = string
    @min_date = min_date
    @allowed_days_in_future = allowed_days_in_future
  end

  attr_reader :string, :min_date, :allowed_days_in_future
  delegate :to_s, to: :string

  def out_of_range?
    return true if min_date && ending.to_date < min_date
    return true if max_date && beginning.to_date > max_date

    false
  end

  def current?
    return true if now? || all?
    return date.today? if day?
    return date.cweek == Date.current.cweek if week?
    return date.month == Date.current.month if month?
    return date.year == Date.current.year if year?
  end

  def past?
    return false if now? || all?

    ending.to_date < Date.current
  end

  def future?
    return false if now? || all?

    beginning.to_date > Date.current
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
      "KW #{date.cweek}, #{date.year}"
    when :month
      I18n.l(date, format: :month)
    when :year
      date.year.to_s
    when :all
      I18n.t('timeframe.all')
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
    trimmed_ending.strftime(format(target_id: :day))
  end

  def corresponding_week
    trimmed_ending.strftime(format(target_id: :week))
  end

  def corresponding_month
    trimmed_ending.strftime(format(target_id: :month))
  end

  def corresponding_year
    trimmed_ending.strftime(format(target_id: :year))
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

  # Ending, but not further than max_date and current date
  def trimmed_ending
    [ending, max_date, Date.current].compact.min
  end

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
