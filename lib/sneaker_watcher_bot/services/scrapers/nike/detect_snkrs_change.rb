module Service
  module Scraper
    module Nike
      class DetectSnkrsChange < Base
        def perform
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
          headers = {
            params: params,
            user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15 Version/13.0.4',
            'appid': 'com.nike.commerce.snkrs.web',
            'nike-api-caller-id': 'nike:snkrs:web:1.0'
          }
          response = RestClient.get("#{base_url}/product_feed/threads/v2", headers)
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          products = parsed_body.dig(:objects)
          products&.each do |product|
            product_properties = product.dig(:publishedContent, :nodes)&.first&.dig(:properties)
            product_name = "#{product_properties[:subtitle]} #{product_properties[:title]}"
            product_img = product.dig(:publishedContent, :properties, :coverCard, :properties, :portraitURL)
            next if product_img.blank? || product_name.blank?
            TelegramBot.new.send_telegram_photo(product_name, product_img[:image])
          end
          # html = Nokogiri::HTML(response.body)
          # html.css('.product-item-info').each do |product|
          #   product_name = product.xpath(".//a[contains(@class, 'product-item-link')]").first.inner_text.strip
          #   product_url = product.xpath(".//a[contains(@class, 'product-item-link')]").first.attributes['href'].value
          #   product_slug = URI.parse(product_url).path.split('/').last
          #   product_img = product.xpath(".//img[contains(@class, 'product-image-photo')]").first.attributes['src'].value
          #   product_hash = {
          #     slug: product_slug,
          #     name: product_name,
          #     url: product_url,
          #     image: product_img
          #   }
          #   next if !relevant_product?(product_name) || # not relevant
          #     !new_product?(product_slug) # not a new product

          #   send_message(product_hash)
          # end
        end

        private

        def whitelisted_products
          @whitelisted_products ||= ENV['OUR_DAILY_DOSE_BASE_LATEST_WHITELISTED_PRODUCTS'].split(",")
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
          message = "<strong>OUR DAILY DOSE LATEST UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def redis_key(identifier)
          "nike_snkrs_#{identifier.downcase}"
        end

        def base_url
          ENV['NIKE_SNKRS_API_BASE_URL']
        end
      end
    end
  end
end
