class Place::VisitList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'visits_page_'.freeze
  public_constant :FRAME_PREFIX

  # `previous_started_at`: see Timeframe::RowGroups
  def initialize(visits:, pagy:, context:, previous_started_at: nil, frame: false)
    super()
    @pagy = pagy
    @context = context
    @groups = Timeframe::RowGroups.new(visits, timeframe: context.timeframe, previous_started_at:)
    @frame = frame
  end

  attr_reader :groups, :pagy, :context, :frame

  # The list of the group alone, with the car and the place of the list
  # A list of a day has its only group already, so its header has no link
  def group_path(group)
    context.list_path(timeframe: group.to_param) unless context.timeframe.day?
  end
end
