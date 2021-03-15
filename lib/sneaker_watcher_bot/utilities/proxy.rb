class Proxy
  class << self
    def rotating
      ENV['ROTATING_PROXY'].presence
    end

    def sticky
    end

    def static
    end
  end
end
