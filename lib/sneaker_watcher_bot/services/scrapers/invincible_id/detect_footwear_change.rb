module Service
  module Scraper
    module InvincibleId
      class DetectFootwearChange < Base
        def self.interval_seconds
          20
        end

        def perform
          response = RestClient.get("#{base_url}/collections/footwear")
          html = Nokogiri::HTML(response.body)
          html.css('.boost-pfs-filter-product-item-grid').take(10).each do |product|
            product_name = product.xpath(".//div[contains(@class, 'grid-view-item--desc-wrapper')]//a").first.inner_text.strip
            product_url = base_url + product.xpath(".//div[contains(@class, 'grid-view-item-image')]//a").first.attributes['href'].value
            product_slug = URI.parse(product_url).path.split('/').last
            product_img = 'https:' + product.xpath(".//div[contains(@class, 'grid-view-item-image')]//img").first.attributes['src'].value
            product_hash = {
              slug: product_slug,
              name: product_name,
              url: product_url,
              image: product_img
            }
            next if !relevant_product?(product_name) || # not relevant
              !new_product?(product_slug) # not a new product

            send_message(product_hash)
          end
        end

        private

        def whitelisted_products
          @whitelisted_products ||= ENV['INVINCIBLE_ID_FOOTWEAR_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def new_product?(identifier)
          key = redis_key(identifier)
          product_cache = SneakerWatcherBot.redis.get(key)
          return true if product_cache.blank?
          SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
          return false
        end

        def redis_expiry
          Time.now + 24.hours
        end

        def send_message(product_hash)
          message = "<strong>INVINCIBLE ID FOOTWEAR UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def redis_key(identifier)
          "invincible_id_footwear_#{identifier.downcase}"
        end

        def base_url
          ENV['INVINCIBLE_ID_BASE_URL']
        end
      end
    end
  end
end
