module Service
  module Scraper
    module Atmos
      class DetectRaffleChange < Base
        def initialize
          @atmos_base_url = ENV['ATMOS_BASE_URL']
        end

        def call
          new_hash = scrape_raffle
          if is_new_product?(new_hash)
            SneakerWatcherBot.redis.set(redis_key, new_hash.to_json)
            message = "*ATMOS RAFFLE UPDATE DETECTED!*\n"\
              "[#{new_hash[:name]}](#{@atmos_base_url}#{new_hash[:url]})"
            TelegramBot.new.send_telegram_photo(message, new_hash[:image])
          end
        end

        def is_new_product?(new_hash)
          @is_new_product ||= begin
            latest_product_raffle_cache = SneakerWatcherBot.redis.get(redis_key)
            return true if latest_product_raffle_cache.blank?
            previous_hash = JSON.parse(latest_product_raffle_cache).deep_symbolize_keys
            previous_hash != new_hash
          end
        end

        def scrape_raffle
          response = RestClient.get("#{@atmos_base_url}/collections/raffle")
          html = Nokogiri::HTML(response.body)
          latest_product_grid = html.css('.product.grid-item').first
          latest_product_url = latest_product_grid.elements.first.attributes['href'].value
          latest_product_name = latest_product_grid.css('.product-title').first.inner_text
          latest_product_img = latest_product_grid.xpath("//*[@id='panel']/section/div[2]/div[2]/div/div[1]/article/a/div[1]/img").first.attributes['src'].value
          latest_product_img = "https:#{latest_product_img}"
          {
            name: latest_product_name,
            url: latest_product_url,
            image: latest_product_img
          }
        end

        private

        def redis_key
          'atmos_latest_product_raffle'
        end
      end
    end
  end
end