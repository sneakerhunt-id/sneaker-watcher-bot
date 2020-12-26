module Service
  module Scraper
    module Atmos
      class DetectRaffleChange < Base
        def self.interval_seconds
          60
        end

        def perform
          response = RestClient.get("#{base_url}/collections/raffle/products.json")
          raw_product_data = JSON.parse(response.body).deep_symbolize_keys
          raw_product_data.dig(:products).take(10).each do |product|
            begin
              product_available = product[:variants].any? {|v| v[:available] == true }
              product_url = "/collections/raffle/products/#{product[:handle]}"
              product_name = product[:title]
              product_img = product[:images]&.first&.dig(:src)
              product_slug = product[:handle]
              product_hash = {
                slug: product_slug,
                name: product_name,
                url: product_url,
                image: product_img
              }
              next if !product_available || # already sold out
                !new_product?(product_hash) # already detected previously

              send_message(product_hash)
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

        private

        def base_url
          ENV['ATMOS_BASE_URL']
        end

        def redis_key(identifier)
          "atmos_latest_product_raffle_#{identifier}"
        end

        def required_attributes?(product_hash)
          # invalid if any of these attribute is blank
          product_hash[:name].blank? || product_hash[:url].blank? || product_hash[:image].blank?
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['ATMOS_COLLECTIONS_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def new_product?(product_hash)
          key = redis_key(product_hash[:slug])
          product_cache = SneakerWatcherBot.redis.get(key)
          return true if product_cache.blank?
          SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
          return false
        end

        def redis_expiry
          Time.now + 8.hours
        end

        def send_message(product_hash)
          message = "<strong>ATMOS RAFFLE UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{base_url}#{product_hash[:url]}'>CHECK IT OUT!</a>"

          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end
      end
    end
  end
end