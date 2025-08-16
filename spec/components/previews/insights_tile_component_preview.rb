# @label InsightsTile
class InsightsTileComponentPreview < ViewComponent::Preview
  # @!group Misc

  def default
    render InsightsTile::Component.new do |tile|
      tile.with_title { 'Title here' }
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
      tile.with_footer { 'Footer content here.' }
    end
  end

  def stripes
    render InsightsTile::Component.new stripes: true do |tile|
      tile.with_title { 'Title here' }
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
      tile.with_footer { 'Footer content here.' }
    end
  end

  def with_extra_class
    render InsightsTile::Component.new css_class: 'font-mono' do |tile|
      tile.with_title { 'Title here' }
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
      tile.with_footer { 'Footer content here.' }
    end
  end

  def with_link
    render InsightsTile::Component.new url: '/#' do |tile|
      tile.with_title { 'Title here' }
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
      tile.with_footer { 'Footer content here.' }
    end
  end

  def without_footer
    render InsightsTile::Component.new do |tile|
      tile.with_title { 'Title here' }
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
    end
  end

  def without_title
    render InsightsTile::Component.new do |tile|
      tile.with_body do
        Number::Component.new(value: 10_000).to_watt_hour(unit: :kilo)
      end
      tile.with_footer { 'Footer content here.' }
    end
  end

  def body_only
    render InsightsTile::Component.new do |tile|
      tile.with_body { 'This is the body' }
    end
  end

  # @!endgroup
end
