class String
  def to_utf8
    force_encoding('UTF-8')
  end
end

class NilClass
  def to_utf8
    nil
  end
end
