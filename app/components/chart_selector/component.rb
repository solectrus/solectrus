class ChartSelector::Component < ViewComponent::Base
  def initialize(field:, timeframe:)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_reader :field, :timeframe

  def field_items
    # TODO: Add savings and co2_savings chart
    (Senec::FIELDS_COMBINED - %w[savings co2_savings]).map do |field|
      MenuItem::Component.new(
        name: title(field),
        field:,
        href: root_path(field:, timeframe:),
        data: {
          'turbo-frame' => 'chart',
          'turbo-action' => 'replace',
          'action' =>
            'stats-with-chart--component#startLoop dropdown--component#toggle',
          'stats-with-chart--component-field-param' => field,
        },
        current: field == @field,
      )
    end
  end

  private

  def title(field)
    if field.in?(%w[bat_fuel_charge])
      "#{I18n.t "senec.#{field}"} in &percnt;".html_safe
    elsif field.in?(%w[autarky consumption])
      "#{I18n.t "calculator.#{field}"} in &percnt;".html_safe
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
