# Distances between two locations on the earth
module Geo
  METERS_PER_DEGREE = 111_195
  private_constant :METERS_PER_DEGREE

  # In meters, with the equirectangular approximation. It is exact enough for
  # some hundred meters.
  def self.distance(latitude, longitude, other_latitude, other_longitude)
    x = (other_longitude - longitude) * Math.cos((latitude + other_latitude) * Math::PI / 360)
    y = other_latitude - latitude

    Math.sqrt((x**2) + (y**2)) * METERS_PER_DEGREE
  end

  # The ranges of latitude and longitude around a location that hold each
  # location within the distance in meters. A degree of longitude gets
  # shorter away from the equator, so its range gets wider.
  def self.box(latitude, longitude, meters)
    delta_latitude = meters.to_f / METERS_PER_DEGREE
    delta_longitude = delta_latitude / Math.cos(latitude * Math::PI / 180)

    [(latitude - delta_latitude)..(latitude + delta_latitude), (longitude - delta_longitude)..(longitude + delta_longitude)]
  end
end
