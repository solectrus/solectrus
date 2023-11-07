class ChartSelector::Component < ViewComponent::Base
  def initialize(field:, timeframe:)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_reader :field, :timeframe

  def field_items
    # TODO: Add savings chart
    (Senec::FIELDS_COMBINED - ['savings']).map do |field|
      {
        name: title(field),
        field:,
        href: root_path(field:, timeframe:),
        data: {
          'turbo-frame' => 'chart',
          'turbo-action' => 'replace',
          'action' => 'stats-with-chart--component#startLoop',
          'stats-with-chart--component-field-param' => field,
        },
      }
    end
  end

  private

  def title(field)
    if field.in?(%w[bat_fuel_charge])
      "#{I18n.t "senec.#{field}"} in &percnt;".html_safe
    elsif field.in?(%w[autarky consumption])
      "#{I18n.t "calculator.#{field}"} in &percnt;".html_safe
    elsif field.in?(%w[savings])
      "#{I18n.t "calculator.#{field}"} in &euro;".html_safe
    elsif field.in?(%w[case_temp])
      "#{I18n.t "senec.#{field}"} in &deg;C".html_safe
    else
      "#{I18n.t "senec.#{field}"} in #{power? ? 'kW' : 'kWh'}"
    end
  end

  def power?
    timeframe.now? || timeframe.day?
  end
end
