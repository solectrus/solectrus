class SummaryBuilder::Component < ViewComponent::Base
  # `charging_sessions` tells the build of each chunk that the days of the page
  # include the days whose sessions wait for the detection (see
  # Summary.missing_or_stale_days). Otherwise a chunk finds other days than
  # the page.
  def initialize(timeframe:, missing_or_stale_days:, charging_sessions: false)
    super()
    @timeframe = timeframe
    @missing_or_stale_days = missing_or_stale_days
    @charging_sessions = charging_sessions
  end

  attr_reader :timeframe, :missing_or_stale_days, :charging_sessions

  # One request per day would spend most of its time on the request itself, so
  # a batch of days is built at once (see Sensor::Summarizer::CHUNK_SIZE) and
  # each chunk gets one frame and one step of the progress bar.
  def chunks
    @chunks ||=
      missing_or_stale_days.each_slice(Sensor::Summarizer::CHUNK_SIZE).to_a
  end

  # Do we need a full progress bar or just a simple loading spinner?
  def loading_spinner?
    missing_or_stale_days.length < 3
  end

  class ChunkComponent < ViewComponent::Base
    def initialize(from:, to:, size: 1, completed: false, charging_sessions: false)
      super()
      @from = from
      @to = to
      @size = size
      @completed = completed
      @charging_sessions = charging_sessions
    end

    attr_reader :from, :to, :size, :completed, :charging_sessions

    def call
      helpers.turbo_frame_tag(dom_id, **turbo_frame_tag_options) do
        tag.div class: css_classes
      end
    end

    private

    def dom_id
      "d_#{from}_#{to}"
    end

    def turbo_frame_tag_options
      {
        'data-src': summary_path(date: from, to:, charging_sessions: (1 if charging_sessions)),
        # A trailing chunk covers fewer days than the others, so the bar shows
        # what it is really worth
        style: "flex: #{size}",
      }
    end

    def css_classes
      "h-10#{' bg-indigo-600 dark:bg-indigo-500 scale-pop' if completed}"
    end
  end
end
