module Service
  module Scraper
    module Atmos
      class DetectCollectionsChange < Base
        def self.interval_seconds
          4
        end

        def perform
          collections = ENV['ATMOS_COLLECTIONS'].split(',').map(&:strip).compact

          collections.each do |collection|
            scrape_collection_products(collection)
          end
        end

        private

        def scrape_collection_products(collection)
          response = RestClient.get("#{base_url}/collections/#{collection}/products.json")
          raw_product_data = JSON.parse(response.body).deep_symbolize_keys
          raw_product_data.dig(:products).take(8).each do |product|
            begin
              product_available = product[:variants].any? {|v| v[:available] == true }
              product_slug = product[:handle]

              if !product_available
                delete_cache(product_slug)
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
                !need_notify?(product_hash) # if new product / new stock

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

        def base_url
          ENV['ATMOS_BASE_URL']
        end

        def redis_key(identifier)
          "atmos_latest_collections_#{identifier}"
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['ATMOS_COLLECTIONS_WHITELISTED_PRODUCTS'].split(",")
            .map(&:strip).map(&:downcase).compact
        end

        def need_notify?(product_hash)
          # check if there's any existing cache yet
          key = redis_key(product_hash[:slug])
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

        def delete_cache(identifier)
          SneakerWatcherBot.redis.del(redis_key(identifier))
        end

        def redis_expiry
          Time.now + 24.hours
        end

        def send_message(product_hash)
          message = "<strong>ATMOS COLLECTIONS UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{base_url}#{product_hash[:url]}'>CHECK IT OUT!</a>"

          message += "\n\n<strong>AVAILABLE SIZE</strong>:\n" if product_hash[:sizes].present?
          product_hash[:sizes].each do |size|
            checkout_link = "#{base_url}/cart/#{size[:id]}:1"
            message += "<strong>#{size[:title]}</strong> "\
              "<a href='#{checkout_link}'>CHECKOUT</a>\n"
          end
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.setex(redis_key(product_hash[:slug]), redis_expiry.to_i, product_hash.to_json)
        end
      end
    end
  end
end
