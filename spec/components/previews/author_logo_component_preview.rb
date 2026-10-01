# @label AuthorLogo
# @logical_path general
class AuthorLogoComponentPreview < ViewComponent::Preview
  def outdated
    render AuthorLogo::Component.new
  end
end
