class GenderizeIoRb::Errors
  class NameNotFound < RuntimeError
    attr_accessor :name
  end

  class ResultError < RuntimeError
    attr_accessor :name
  end
end
