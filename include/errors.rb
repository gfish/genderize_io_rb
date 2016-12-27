class GenderizeIoRb::Errors
  class NameNotFound < RuntimeError
    attr_accessor :name
  end

  class LimitReached < RuntimeError
    attr_accessor :name
  end
end
