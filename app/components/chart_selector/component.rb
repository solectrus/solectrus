class ChartSelector::Component < ViewComponent::Base
  def initialize(field:, timeframe:)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_reader :field, :timeframe

  def field_items
    Senec::FIELDS_COMBINED.map do |field|
      {
        name: title(field),
        field:,
        href: root_path(field:, timeframe:),
        data: {
          'turbo-frame' => 'chart',
          'turbo-action' => 'replace',
        },
      }
    end
  end

  private

  def title(field)
    if field.in?(%w[bat_fuel_charge autarky consumption])
      "#{I18n.t "senec.#{field}"} in %"
    elsif field.in?(%w[case_temp])
      "#{I18n.t "senec.#{field}"} in °C"
    else
      "#{I18n.t "senec.#{field}"} in #{power? ? 'kW' : 'kWh'}"
    end
  end

  def power?
    timeframe.now? || timeframe.day?
  end
end
