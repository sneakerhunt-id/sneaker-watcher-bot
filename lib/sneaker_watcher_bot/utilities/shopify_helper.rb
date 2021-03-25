module ShopifyHelper
  def scrape_collection_products(prefix, base_url, collection, fetch_limit, redis_expiry)
    collection_url = "#{base_url}/collections/#{collection}/products.json"
    proxy_key = "#{prefix}_proxy"

    begin
      response = RestClient::Request.execute(
        method: :get,
        url: collection_url,
        headers: { params: { limit: fetch_limit } },
        proxy: ::Proxy.get_current_static_proxy(proxy_key),
        timeout: 10,
        open_timeout: 10
      )
    rescue => e
      proxy = ::Proxy.rotate_static_proxy(proxy_key)
      log_object = {
        tags: self.class.name.underscore,
        message: "Rotate static proxy of #{proxy_key} because of error: #{e.message}",
        proxy: proxy
      }
      SneakerWatcherBot.logger.info(log_object)
      raise
    end

    raw_product_data = JSON.parse(response.body).deep_symbolize_keys
    raw_product_data.dig(:products).take(fetch_limit).each do |product|
      begin
        product_available = product[:variants].any? {|v| v[:available] == true }
        product_slug = product[:handle]

        if !product_available
          delete_cache(prefix, product_slug)
          next
        end

        product_name = product[:title]
        next if !relevant_product?(product_name) # not relevant

        product_url = "/collections/#{collection}/products/#{product[:handle]}"
        product_img = product[:images]&.first&.dig(:src)
        product_hash = {
          slug: product_slug,
          name: product_name,
          url: product_url,
          image: product_img
        }

        product_hash[:sizes] = []
        product[:variants].each do |variant|
          next if !variant[:available]
          product_hash[:sizes] << {
            id: variant[:id],
            title: variant[:option1]
          }
        end

        next if raffle?(product[:tags].join(',')) || # is a raffle
          !need_notify?(prefix, product_hash, redis_expiry) # if new product / new stock

        send_message(prefix, product_hash, redis_expiry)
      rescue => e
        log_object = {
          tags: self.class.name.underscore,
          message: e.message,
          backtrace: e.backtrace.take(5),
          instagram_username: @username
        }
        SneakerWatcherBot.logger.error(log_object)
      end
    end
  end

  def need_notify?(prefix, product_hash, redis_expiry)
    # check if there's any existing cache yet
    key = redis_key(prefix, product_hash[:slug])
    product_cache = SneakerWatcherBot.redis.get(key)
    return true if product_cache.blank?

    # if old cache exists,
    # determine whether new cache has any new available sizes (new stock)
    old_hash = JSON.parse(product_cache).deep_symbolize_keys
    new_stock = (product_hash[:sizes] - old_hash[:sizes]).any?
    return true if new_stock

    # save latest cache to accommodate stock/data changes
    SneakerWatcherBot.redis.setex(key, redis_expiry.to_i, product_hash.to_json)
    return false
  end

  def delete_cache(prefix, identifier)
    SneakerWatcherBot.redis.del(redis_key(prefix, identifier))
  end

  def send_message(prefix, product_hash, redis_expiry)
    message = "<strong>#{prefix.humanize.upcase} COLLECTIONS UPDATE DETECTED!</strong>\n"\
      "#{product_hash[:name]}\n"\
      "<a href='#{base_url}#{product_hash[:url]}'>CHECK IT OUT!</a>"

    message += "\n\n<strong>AVAILABLE SIZE</strong>:\n" if product_hash[:sizes].present?
    product_hash[:sizes].each do |size|
      checkout_link = "#{base_url}/cart/#{size[:id]}:1"
      message += "<strong>#{size[:title]}</strong> "\
        "<a href='#{checkout_link}'>CHECKOUT</a>\n"
    end
    TelegramBot.new.send_telegram_photo(message, product_hash[:image])
    SneakerWatcherBot.redis.setex(redis_key(prefix, product_hash[:slug]), redis_expiry.to_i, product_hash.to_json)
  end

  def redis_key(prefix, identifier)
    "#{prefix}_latest_collections_#{identifier}"
  end
end
