module Service
  module Scraper
    module Zalora
      class DetectNikeChange < Base
        def self.interval_seconds
          10
        end

        def perform
          response = RestClient.get("#{base_url}/_c/v1/desktop/list_catalog_full", request_headers)
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          products = parsed_body.dig(:response, :docs)
          products&.each do |product|
            product_meta = product.dig(:meta)
            product_name = "#{product_meta[:brand]} #{product_meta[:name]}"
            product_img = product.dig(:image)
            product_slug = product.dig(:link)
            product_url = "#{base_url}/#{product_slug}"
            product_sizes = []
            index = 1
            product.dig(:available_sizes)&.each do |size|
              product_sizes << {
                index: index,
                size: size[:size],
                description: "#{product_meta[:sizesystembrand]} #{size[:label]}"
              }
            end
            product_hash = {
              name: product_name,
              slug: product_slug,
              url: product_url,
              image: product_img,
              sizes: product_sizes
            }

            next if product_img.blank? ||
              product_name.blank? ||
              product_sizes.blank? ||
              product_slug.blank? ||
              !relevant_product?(product_name) ||
              !new_product?(product_hash)
            send_message(product_hash)
          end
        end

        private

        def params
          {
            sort: 'latest arrival',
            dir: 'desc',
            offset: 0,
            limit: 50,
            brand: 126, # nike
            special_price: false,
            all_products: false,
            new_products: false,
            top_sellers: false,
            catalogtype: 'Main',
            lang: 'id',
            is_brunei: false,
            search_suggest: false,
            enable_visual_sort: false,
            enable_filter_ads: true,
            compact_catalog_desktop: false,
            name_search: false,
            solr7_support: false,
            pick_for_you: false,
            learn_to_sort_catalog: false,
            is_multiple_source: true,
            enable_similar_term: true
          }
        end

        def request_headers
          # TODO: create a user agent strings pool and randomized from there
          {
            params: params
            # TODO: investigate Zalora banning mechanism
            # user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15 Version/13.0.4'
          }
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['ZALORA_NIKE_WHITELISTED_PRODUCTS'].split(",")
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

        def redis_key(identifier)
          prefix = "zalora_nike"
          "#{prefix}_#{identifier.downcase}"
        end

        def send_message(product_hash)
          message = "<strong>ZALORA NIKE UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"

          message += "\n\n<strong>AVAILABLE SIZE</strong>:\n" if product_hash[:sizes].present?
          product_hash[:sizes].each { |size| message += "<strong>#{size[:description]}</strong>\n" }
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def base_url
          ENV['ZALORA_BASE_URL']
        end
      end
    end
  end
end
