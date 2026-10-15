class Place::VisitList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'visits_page_'.freeze
  public_constant :FRAME_PREFIX

  def initialize(visits:, pagy:, context:, frame: false)
    super()
    @visits = visits
    @pagy = pagy
    @context = context
    @frame = frame
  end

  attr_reader :visits, :pagy, :context, :frame
end
