class SummaryBuilder::Component < ViewComponent::Base
  def initialize(timeframe:, missing_days:)
    super()
    @timeframe = timeframe
    @missing_days = missing_days
  end

  attr_reader :timeframe, :missing_days

  def days
    @days ||= beginning_date..ending_date
  end

  def beginning_date
    if timeframe.year?
      # We want to show the full year, including the days before installation
      timeframe.beginning.to_date
    else
      timeframe.effective_beginning_date
    end
  end

  def ending_date
    if timeframe.year?
      # We want to show the full year, including the remaining days of the year
      timeframe.ending.to_date
    else
      timeframe.effective_ending_date
    end
  end

  class DayComponent < ViewComponent::Base
    def initialize(date:, is_missing: false, just_created: false)
      super()
      @date = date
      @is_missing = is_missing
      @just_created = just_created
    end

    attr_reader :date, :just_created

    def call
      helpers.turbo_frame_tag(dom_id, **turbo_frame_tag_options) do
        tag.div class: css_classes
      end
    end

    private

    def missing?
      @is_missing
    end

    def out_of_range?
      date < Rails.application.config.x.installation_date || date > Date.current
    end

    def turbo_frame_tag_options
      return unless missing?

      { data: { src: summary_path(date:), sequential_frames_target: 'frame' } }
    end

    def css_classes
      [
        'summary-day',
        (
          if missing?
            'bg-gray-300 dark:bg-gray-800'
          elsif out_of_range?
            'bg-gray-50 dark:bg-black'
          else
            ['bg-indigo-600 dark:bg-indigo-900', just_created && 'scale-pop']
          end
        ),
      ]
    end

    def dom_id
      "date_#{date}"
    end
  end
end
