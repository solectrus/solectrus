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
    unless string.match?(self.class.regex)
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
      'Seit Inbetriebnahme'
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

  def next
    return if id.in?(%i[now all])

    change(+1)&.strftime(format)
  end

  def previous
    return if id.in?(%i[now all])

    change(-1)&.strftime(format)
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

  private

  # Ending, but not further than max_date and current date
  def trimmed_ending
    [ending, max_date, Date.current].compact.min
  end

  def date
    case id
    when :now
      Time.current
    when :day
      Date.parse(string)
    when :week
      Date.commercial(*string.split('-W').map(&:to_i))
    when :month
      Date.parse("#{string}-01")
    when :year
      Date.parse("#{string}-01-01")
    end
  end

  def change(amount)
    new_date =
      case id
      when :day
        date + amount.day
      when :week
        date + amount.week
      when :month
        date + amount.month
      when :year
        date + amount.year
      end

    return if new_date < min_date
    return if new_date > max_date
    new_date
  end

  def max_date
    day? ? (Date.current + allowed_days_in_future.days) : Date.current
  end

  FORMAT = {
    now: 'Heute, %H:%M Uhr',
    day: '%Y-%m-%d',
    week: '%Y-W%W',
    month: '%Y-%m',
    year: '%Y',
  }.freeze

  private_constant :FORMAT

  def format(target_id: id)
    FORMAT[target_id]
  end
end
