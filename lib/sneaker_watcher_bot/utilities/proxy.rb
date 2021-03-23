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

    def rotate_static_proxy(identifier)
      return nil if ::Proxy.static_proxy_pools.blank?

      proxy_cache = SneakerWatcherBot.redis.get(identifier)
      if proxy_cache.present?
        static_proxy_count = ::Proxy.static_proxy_pools.count
        order_index = ::Proxy.static_proxy_pools.find_index { |proxy| proxy == proxy_cache }
        order_index = (order_index+1) % static_proxy_count
        proxy_cache = ::Proxy.static_proxy_pools[order_index]
      else
        proxy_cache = ::Proxy.static_proxy_pools.first
      end
      SneakerWatcherBot.redis.set(identifier, proxy_cache)
      proxy_cache
    end

    def get_current_static_proxy(identifier)
      return nil if ::Proxy.static_proxy_pools.blank?

      proxy_cache = SneakerWatcherBot.redis.get(identifier)
      return proxy_cache if proxy_cache.present?

      proxy_cache = ::Proxy.static_proxy_pools.first
      SneakerWatcherBot.redis.set(identifier, proxy_cache)
      proxy_cache
    end
  end
end
