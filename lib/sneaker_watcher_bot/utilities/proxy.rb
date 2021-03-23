class Proxy
  class << self
    def rotating
      ENV['ROTATING_PROXY'].presence
    end

    def sticky
    end

    def static_proxy_pools
      ENV['STATIC_PROXY_POOLS'].split(',').map(&:strip).compact
    end
  end
end
