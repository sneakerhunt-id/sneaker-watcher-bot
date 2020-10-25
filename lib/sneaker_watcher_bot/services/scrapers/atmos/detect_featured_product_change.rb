module Service
  module Scraper
    module Atmos
      class DetectFeaturedProductChange < Base
        def initialize
          @atmos_base_url = ENV['ATMOS_BASE_URL']
        end

        def call
          new_hash = scrape_featured_product
          if is_new_product?(new_hash)
            message = "*ATMOS FEATURED PRODUCT UPDATE DETECTED!*\n"\
              "#{new_hash[:name]}\n"\
              "[CHECK IT OUT!](#{@atmos_base_url}#{new_hash[:url]})"
            TelegramBot.new.send_telegram_photo(message, new_hash[:image])
            SneakerWatcherBot.redis.set(redis_key, new_hash.to_json)
          end
        end

        def is_new_product?(new_hash)
          @is_new_product ||= begin
            latest_product_featured_product_cache = SneakerWatcherBot.redis.get(redis_key)
            return true if latest_product_featured_product_cache.blank?
            previous_hash = JSON.parse(latest_product_featured_product_cache).deep_symbolize_keys
            previous_hash != new_hash
          end
        end

        def scrape_featured_product
          response = RestClient.get("#{@atmos_base_url}")
          html = Nokogiri::HTML(response.body)
          latest_product_grid = html.css('.product.grid-item').first
          latest_product_url = latest_product_grid.elements.first.attributes['href'].value
          latest_product_name = latest_product_grid.css('.product-title').first.inner_text
          latest_product_img = latest_product_grid.css('.product-featured-image').first.elements.first.attributes['src'].value
          latest_product_img = "https:#{latest_product_img}"
          {
            name: latest_product_name,
            url: latest_product_url,
            image: latest_product_img
          }
        end

        private

        def redis_key
          'atmos_latest_product_featured_products'
        end
      end
    end
  end
end