class GenderizeIoRb::Errors
  class NameNotFound < RuntimeError
    attr_accessor :name
  end

  class LimitReached < RuntimeError
    attr_accessor :name
  end

  class InvalidApiKey < RuntimeError
    attr_accessor :name
  end

  class UnknownError < RuntimeError
    attr_accessor :name
  end
end
