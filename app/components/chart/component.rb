class Chart::Component < ViewComponent::Base
  def initialize(field:, timeframe:, url:)
    super
    @field = field
    @timeframe = timeframe
    @url = url
  end
  attr_reader :field, :timeframe, :url

  def options # rubocop:disable Metrics/MethodLength
    {
      maintainAspectRatio: false,
      legend: false,
      title: {
        fontSize: 20,
        display: true,
        text: title
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300
      },
      elements: {
        point: {
          radius: 0,
          hitRadius: 5,
          hoverRadius: 5
        }
      },
      tooltips: {
        displayColors: false,
        titleFontSize: 16,
        bodyFontSize: 20
      },
      scales: {
        xAxes: [
          {
            gridLines: {
              drawOnChartArea: false
            },
            ticks: {
              maxRotation: 0
            },
            offset: chart_type.bar?,
            distribution: chart_type.line? ? 'linear' : 'series',
            type: 'time',
            time: {
              'now'   => { unit: 'minute', stepSize: 15, displayFormats: { minute: 'HH:mm' }, tooltipFormat: 'HH:mm:ss' },
              'day'   => { unit: 'hour',   stepSize: 3,  displayFormats: { hour:   'HH:mm' }, tooltipFormat: 'HH:mm' },
              'week'  => { unit: 'day',    stepSize: 1,  displayFormats: { day:    'ddd'   }, tooltipFormat: 'dddd, DD.MM.YYYY' },
              'month' => { unit: 'day',    stepSize: 2,  displayFormats: { day:    'D'     }, tooltipFormat: 'dddd, DD.MM.YYYY' },
              'year'  => { unit: 'month',  stepSize: 1,  displayFormats: { month:  'MMM'   }, tooltipFormat: 'MMMM YYYY' },
              'all'   => { unit: 'year',   stepSize: 1,  displayFormats: { year:   'YYYY'  }, tooltipFormat: 'YYYY' }
            }[timeframe]
          }
        ],
        yAxes: [
          {
            ticks: {
              beginAtZero: true,
              maxTicksLimit: 4
            }
          }
        ]
      }
    }
  end

  def chart_type
    (timeframe.in?(%w[now day]) ? 'line' : 'bar').inquiry
  end

  def title
    if field == 'bat_fuel_charge'
      "#{I18n.t "senec.#{field}"} in %"
    else
      "#{I18n.t "senec.#{field}"} in #{timeframe.in?(%w[now day]) ? 'kW' : 'kWh'}"
    end
  end
end
