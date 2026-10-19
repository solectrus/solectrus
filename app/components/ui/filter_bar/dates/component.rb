# The dates of a filter as a pill of Ui::FilterBar: a calendar year, a
# range, or one end of it. Without dates, nothing. `remove_path:` is the
# address without the dates (see Ui::FilterBar::Pill).
class Ui::FilterBar::Dates::Component < ViewComponent::Base
  def initialize(from:, to:, remove_path: nil)
    super()
    @from = from
    @to = to
    @remove_path = remove_path
  end

  def render? = @from.present? || @to.present?

  def call
    render Ui::FilterBar::Pill::Component.new(icon: 'calendar', remove_path: @remove_path).with_content(text)
  end

  private

  def text
    return @from.year.to_s if year?
    return "#{l(@from)} – #{l(@to)}" if @from && @to
    return "#{t('.from')} #{l(@from)}" if @from

    "#{t('.to')} #{l(@to)}"
  end

  def year? = @from && @to && @from == @from.beginning_of_year && @to == @from.end_of_year
end
