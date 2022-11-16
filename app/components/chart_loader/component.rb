class ChartLoader::Component < ViewComponent::Base
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
          type: 'timeseries',
          ticks:
            {
              now: {
                stepSize: 15,
                maxRotation: 0,
              },
              day: {
                stepSize: 3,
                maxRotation: 0,
              },
              week: {
                stepSize: 1,
                maxRotation: 0,
              },
              month: {
                stepSize: 2,
                maxRotation: 0,
              },
              year: {
                stepSize: 1,
                maxRotation: 0,
              },
              all: {
                stepSize: 1,
                maxRotation: 0,
              },
            }[
              timeframe.id
            ],
          time:
            {
              now: {
                unit: 'minute',
                displayFormats: {
                  minute: 'HH:mm',
                },
                tooltipFormat: 'HH:mm:ss',
              },
              day: {
                unit: 'hour',
                displayFormats: {
                  hour: 'HH:mm',
                },
                tooltipFormat: 'HH:mm',
              },
              week: {
                unit: 'day',
                displayFormats: {
                  day: 'eee',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
              },
              month: {
                unit: 'day',
                displayFormats: {
                  day: 'd',
                },
                tooltipFormat: 'eeee, dd.MM.yyyy',
              },
              year: {
                unit: 'month',
                displayFormats: {
                  month: 'MMM',
                },
                tooltipFormat: 'MMMM yyyy',
              },
              all: {
                unit: 'year',
                displayFormats: {
                  year: 'yyyy',
                },
                tooltipFormat: 'yyyy',
              },
            }[
              timeframe.id
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
    (power? ? 'line' : 'bar').inquiry
  end

  def title
    if field.in?(%w[bat_fuel_charge autarky consumption])
      "#{I18n.t "senec.#{field}"} in %"
    else
      "#{I18n.t "senec.#{field}"} in #{power? ? 'kW' : 'kWh'}"
    end
  end

  def power?
    timeframe.now? || timeframe.day?
  end
end
