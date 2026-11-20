class InsightsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation
  include RefererNamespace
  include SheetPage

  def index
    if turbo_frame_request?
      render :index
    else
      # Fallback: the home page that shows this sensor, not always the balance
      redirect_to helpers.sensor_home_path(sensor.name, timeframe:)
    end
  end

  helper_method :controller_namespace

  private

  # The insights of a chart of the car page show a visitor its data up to the
  # latest public day, like the chart (see Car::AdminOnlyDays)
  helper_method def timeframe
    return if permitted_params[:timeframe].blank?

    @timeframe ||= begin
      frame = Timeframe.new(permitted_params[:timeframe])
      admin? || frame.now? || !sensor.is_a?(Sensor::Definitions::CarPageChart) ? frame : Car::AdminOnlyDays.public_timeframe(frame)
    end
  end

  # The page that holds the frame decides which navigation the insights belong
  # to. A browser does not always send a referer -- its referrer policy can
  # remove it -- and the balance is then the default.
  def controller_namespace
    referer_namespace
  end

  # A row of the trend overview loads the insights into the frame of its
  # sheet, one level below the overview (see TrendsController)
  helper_method def trend_overview?
    return @trend_overview if defined?(@trend_overview)

    @trend_overview =
      sheet_page? && TrendOverview.available?(page: controller_namespace, sensor:, timeframe:)
  end

  # The earlier period of the trend overview above the insights
  helper_method def compared_with
    TrendOverview.base_for(timeframe, params[:base])
  end
  # The figures then and now below the trend overview. The whole time has
  # no earlier period.
  helper_method def comparison
    @comparison ||= Insights::Comparison.for(sensor:, timeframe:, base_timeframe: (Trend.base_timeframe(timeframe, compared_with) unless timeframe.all?), car: params[:car])
  end
end
