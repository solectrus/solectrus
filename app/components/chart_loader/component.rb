class ChartLoader::Component < ViewComponent::Base
  def initialize(field:, period:, url:)
    super
    @field = field
    @period = period
    @url = url
  end
  attr_reader :field, :period, :url

  def options # rubocop:disable Metrics/MethodLength
    {
      maintainAspectRatio: false,
      plugins: {
        legend: false,
        title: {
          display: true,
          font: {
            size: 20,
          },
          text: title,
        },
        tooltip: {
          displayColors: false,
          titleFont: {
            size: 16,
          },
          bodyFont: {
            size: 20,
          },
        },
      },
      animation: {
        easing: 'easeOutQuad',
        duration: 300,
      },
      elements: {
        point: {
          radius: 0,
          hitRadius: 5,
          hoverRadius: 5,
        },
      },
      scales: {
        x: {
          stacked: true,
          grid: {
            drawOnChartArea: false,
          },
          ticks: {
            maxRotation: 0,
          },
          type: 'timeseries',
          time:
            {
              'now' => {
                unit: 'minute',
                stepSize: 15,
                displayFormats: {
                  minute: 'HH:mm',
                },
                tooltipFormat: 'HH:mm:ss',
              },
              'day' => {
                unit: 'hour',
                stepSize: 3,
                displayFormats: {
                  hour: 'HH:mm',
                },
                tooltipFormat: 'HH:mm',
              },
              'week' => {
                unit: 'day',
                stepSize: 1,
                displayFormats: {
                  day: 'eee',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
              },
              'month' => {
                unit: 'day',
                stepSize: 2,
                displayFormats: {
                  day: 'd',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
              },
              'year' => {
                unit: 'month',
                stepSize: 1,
                displayFormats: {
                  month: 'MMM',
                },
                tooltipFormat: 'MMMM yyyy',
              },
              'all' => {
                unit: 'year',
                stepSize: 1,
                displayFormats: {
                  year: 'yyyy',
                },
                tooltipFormat: 'yyyy',
              },
            }[
              period
            ],
        },
        y: {
          ticks: {
            beginAtZero: true,
            maxTicksLimit: 4,
          },
        },
      },
    }
  end

  def type
    (period.in?(%w[now day]) ? 'line' : 'bar').inquiry
  end

  def title
    if field.in?(%w[bat_fuel_charge autarky])
      "#{I18n.t "senec.#{field}"} in %"
    else
      "#{I18n.t "senec.#{field}"} in #{period.in?(%w[now day]) ? 'kW' : 'kWh'}"
    end
  end
end
