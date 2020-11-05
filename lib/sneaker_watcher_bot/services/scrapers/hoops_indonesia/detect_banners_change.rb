module Service
  module Scraper
    module HoopsIndonesia
      class DetectBannersChange < Base
        def perform
          response = RestClient.get("#{base_url}")
          html = Nokogiri::HTML(response.body)
          html.xpath("//*[@id='pos-slideshow-home']//a//img").each do |img|
            # check if sold
            product_sold_out = img.parent.parent.xpath(".//*[contains(text(),'sold')]")
            product_url = img.parent.attributes['href'].value
            product_name = URI(img.parent.attributes['href'].value).path.split('/').last
            product_img = img.attributes['src'].value
            product_hash = {
              name: product_name,
              url: product_url,
              image: product_img
            }
            next if (!relevant_product?(product_url) && # not relevant
              !raffle?(product_url)) ||
              !new_product?(product_name) # not a new product

              send_message(product_hash)
          end
        end

        private

        def whitelisted_products
          @whitelisted_products ||= ENV['HOOPS_INDONESIA_BANNERS_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def redis_key(identifier)
          "hoops_indonesia_latest_banners_#{identifier}"
        end

        def new_product?(identifier)
          key = redis_key(identifier)
          product_cache = SneakerWatcherBot.redis.get(key)
          return true if product_cache.blank?
          SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
          return false
        end

        def base_url
          ENV['HOOPS_INDONESIA_BASE_URL']
        end

        def redis_expiry
          Time.now + 24.hours
        end

        def send_message(product_hash)
          message = "*HOOPS INDONESIA BANNERS UPDATE DETECTED!*\n"\
            "[CHECK IT OUT!](#{base_url}#{product_hash[:url]})"
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:name]), product_hash.to_json)
        end
      end
    end
  end
end
