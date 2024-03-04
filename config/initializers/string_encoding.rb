class String
  def to_utf8
    encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end
end

class NilClass
  def to_utf8
    nil
  end
end
