module Service
  module Scraper
    module Nike
      class DetectSnkrsChange < Base
        def self.interval_seconds
          600
        end

        def perform
          response = RestClient.get("#{api_base_url}/product_feed/threads/v2", request_headers)
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          products = parsed_body.dig(:objects)
          products&.each do |product|
            product_properties = product.dig(:publishedContent, :nodes)&.first&.dig(:properties)
            product_id = product_properties.dig(:actions)&.find {|a| a[:actionType] == 'cta_buying_tools'}&.dig(:product, :productId)
            product_name = "#{product_properties[:subtitle]} #{product_properties[:title]}"
            product_img = product.dig(:publishedContent, :properties, :coverCard, :properties, :portraitURL)
            product_release_time = product.dig(:productInfo)&.first&.dig(:launchView, :startEntryDate)
            product_slug = product.dig(:productInfo)&.first&.dig(:productContent, :slug)
            product_out_of_stock = product.dig(:productInfo)&.first&.dig(:productContent, :outOfStock).present?
            product_url = "#{web_base_url}/t/#{product_slug}"
            product_sizes = []
            index = 1
            product.dig(:productInfo)&.each do |product_info|
              product_id = product_info.dig(:launchView, :productId)
              next if product_id.nil?
              product_info.dig(:skus)&.each do |sku|
                size = sku.dig(:countrySpecifications)&.first
                nike_size = sku.dig(:nikeSize)
                next if nike_size.nil?
                product_sizes << {
                  index: index,
                  id: product_id,
                  size: nike_size,
                  description: "#{size.dig(:localizedSizePrefix)} #{size.dig(:localizedSize)}"
                }
                index += 1
              end
            end

            next if product_out_of_stock ||
              product_img.blank? ||
              product_name.blank? ||
              !relevant_product?(product_name) ||
              product_release_time.blank? ||
              product_sizes.blank? ||
              past_release?(product_release_time) ||
              !new_product?(product_slug)
            product_hash = {
              name: product_name,
              slug: product_slug,
              url: product_url,
              image: product_img,
              release_time: product_release_time,
              sizes: product_sizes
            }
            send_message(product_hash)
          end
        end

        private

        def past_release?(product_release_time)
          Time.parse(product_release_time) < Time.now
        end

        def request_headers
          filters = %w[
            marketplace(ID)
            language(en-GB)
            channelId(010794e5-35fe-4e32-aaff-cd2c74f89d61)
            exclusiveAccess(true,false)
          ]
          fields = %w[
            active id lastFetchTime productInfo publishedContent.nodes publishedContent.subType publishedContent.properties.coverCard
            publishedContent.properties.productCard publishedContent.properties.products publishedContent.properties.publish.collections
            publishedContent.properties.relatedThreads publishedContent.properties.threadType publishedContent.properties.custom
            publishedContent.properties.title
          ]
          params = {
            anchor: 0,
            count: 21,
            filter: filters.join(','),
            fields: fields.join(',')
          }
          # TODO: create a user agent strings pool and randomized from there
          {
            params: params,
            user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15 Version/13.0.4',
            'appid': 'com.nike.commerce.snkrs.web',
            'nike-api-caller-id': 'nike:snkrs:web:1.0'
          }
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['NIKE_SNKRS_WHITELISTED_PRODUCTS'].split(",")
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
          message = "<strong>NIKE SNKRS UPDATE DETECTED!</strong>\n"\
            "NAME:\n#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>\n\n"\
            "RELEASE TIME:\n#{Time.parse(product_hash[:release_time]).in_time_zone("Jakarta").strftime('%d %B %Y at %H:%M WIB')}\n\n"\
            "EARLY CHECKOUT LINK WILL BE PROVIDED #{ENV.fetch('NIKE_SNKRS_REMINDER_HOUR', 2)} HOURS PRIOR TO RELEASE!"
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def redis_key(identifier)
          "nike_snkrs_web_#{identifier.downcase}"
        end

        def api_base_url
          ENV['NIKE_SNKRS_API_BASE_URL']
        end

        def web_base_url
          ENV['NIKE_SNKRS_WEB_BASE_URL']
        end
      end
    end
  end
end
