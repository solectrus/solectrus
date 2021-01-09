class NavComponentPreview < ViewComponent::Preview
  def with_items
    render NavComponent.new(
      items: [
        [ 'one', '/one' ],
        [ 'two', '/two' ],
        [ 'three', '/three' ]
      ]
    )
  end
end
