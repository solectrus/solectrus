# @label AuthorLogo
class AuthorLogoComponentPreview < ViewComponent::Preview
  def outdated
    render AuthorLogo::Component.new
  end
end
