module Service
  module Scraper
    module HoopsIndonesia
      class DetectJordansChange < Base
        AIR_JORDAN = 'AIR JORDAN'

        def call
          new_hash = scrape_new_jordan
          if !new_hash.blank? && is_new_product?(new_hash)
            message = "*HOOPS INDONESIA JORDANS UPDATE DETECTED!*\n"\
              "#{new_hash[:name]}\n"\
              "[CHECK IT OUT!](#{base_url}#{new_hash[:url]})"
            TelegramBot.new.send_telegram_photo(message, new_hash[:image])
            SneakerWatcherBot.redis.set(redis_key, new_hash.to_json)
          end
        end

        def is_new_product?(new_hash)
          @is_new_product ||= begin
            latest_cache = SneakerWatcherBot.redis.get(redis_key)
            return true if latest_cache.blank?
            previous_hash = JSON.parse(latest_cache).deep_symbolize_keys
            previous_hash != new_hash
          end
        end

        def scrape_new_jordan
          response = RestClient.get("#{base_url}/15-jordan")
          html = Nokogiri::HTML(response.body)
          new_items = html.css('.new-box')
          new_items.each do |new|
            latest_product_name = new.parent.xpath(".//a[contains(@class,'product_img_link')]").first.attributes['title'].value
            next unless contains_keyword?(latest_product_name)
            latest_product_url = new.parent.xpath(".//a[contains(@class,'product_img_link')]").first.attributes['href'].value
            latest_product_img = new.parent.xpath(".//img").first.attributes['src'].value
            return {
              name: latest_product_name,
              url: latest_product_url,
              image: latest_product_img
            }
          end
          {}
        end

        private

        def contains_keyword?(name)
          name.upcase =~ /#{AIR_JORDAN}/
        end

        def redis_key
          'hoops_indonesia_latest_product_jordans'
        end

        def base_url
          ENV['HOOPS_INDONESIA_BASE_URL']
        end
      end
    end
  end
end