class SummaryBuilder::Component < ViewComponent::Base
  def initialize(timeframe:, missing_or_stale_days:)
    super()
    @timeframe = timeframe
    @missing_or_stale_days = missing_or_stale_days
  end

  attr_reader :timeframe, :missing_or_stale_days

  # Do we need a full progress bar or just a simple loading spinner?
  def loading_spinner?
    missing_or_stale_days.length < 3
  end

  class DayComponent < ViewComponent::Base
    with_collection_parameter :date

    def initialize(date:, completed: false)
      super()
      @date = date
      @completed = completed
    end

    attr_reader :date, :completed

    def call
      helpers.turbo_frame_tag(dom_id, **turbo_frame_tag_options) do
        tag.div class: css_classes
      end
    end

    private

    def dom_id
      "d_#{date}"
    end

    def turbo_frame_tag_options
      { 'data-src': summary_path(date:) }
    end

    def css_classes
      "h-10#{' bg-indigo-600 dark:bg-indigo-500 scale-pop' if completed}"
    end
  end
end
