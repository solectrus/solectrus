class SummaryBuilder::Component < ViewComponent::Base
  def initialize(timeframe:, missing_days:)
    super()
    @timeframe = timeframe
    @missing_days = missing_days
  end

  attr_reader :timeframe, :missing_days

  def days
    @days ||=
      (timeframe.effective_beginning_date..timeframe.effective_ending_date).to_a
  end

  class DayComponent < ViewComponent::Base
    def initialize(date:, is_missing: false)
      super()
      @date = date
      @is_missing = is_missing
      @dom_id = "date_#{date}"
    end

    attr_reader :date, :is_missing, :dom_id

    def call
      helpers.turbo_frame_tag(dom_id, **turbo_frame_tag_options) do
        tag.div class: css_classes
      end
    end

    private

    def turbo_frame_tag_options
      return unless is_missing

      { data: { src: summary_path(date:), sequential_frames_target: 'frame' } }
    end

    def css_classes
      [
        'summary-day',
        (
          if is_missing
            'bg-gray-300 dark:bg-gray-800'
          else
            'bg-indigo-600 dark:bg-indigo-900 scale-pop'
          end
        ),
      ]
    end
  end
end
