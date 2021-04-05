module Service
  module Scraper
    module TheAthletesFootId
      class DetectSneakersChange < Base
        def self.interval_seconds
          3
        end

        def perform
          url = "#{api_url}/api/products/search"
          response = RestClient::Request.execute(
            method: :get,
            url: url,
            headers: request_headers,
            proxy: ::Proxy.get_current_static_proxy(proxy_key),
            timeout: 8,
            open_timeout: 8
          )
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          products = parsed_body.dig(:data)&.first&.dig(:products)&.take(10)
          products.each do |product|
            product_id = product[:productCode]
            product_url = "#{base_url}#{product[:pageUrl]}"
            product_name = product[:productName]
            product_img = product[:images].first
            product_hash = {
              id: product_id,
              name: product_name,
              url: product_url,
              image: product_img
            }
            next if !relevant_product?(product_name) || # not relevant
              !new_product?(product_id) # not a new product
            send_message(product_hash)
          end
        end

        private

        def request_headers
          {
            params: {
              sc: '4131e652-efdc-38e5-8368-ae046e364262',
              sort: 'listtime_desc',
              nid: '6494',
              pr: '629300-3119200'
            }
          }
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['THE_ATHLETES_FOOT_ID_SNEAKERS_WHITELISTED_PRODUCTS'].split(",")
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
          Time.now + 15.minutes
        end

        def proxy_key
          'the_athletes_foot_id_proxy'
        end

        def send_message(product_hash)
          message = "<strong>THE ATHLETES FOOT ID SNEAKERS UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:id]), product_hash.to_json)
        end

        def redis_key(identifier)
          "the_athletes_foot_id_sneakers_#{identifier}"
        end

        def base_url
          ENV['THE_ATHLETES_FOOT_ID_BASE_URL']
        end

        def api_url
          ENV['THE_ATHLETES_FOOT_ID_API_URL']
        end
      end
    end
  end
end