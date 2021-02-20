module Service
  module Scraper
    module SeekIndonesia
      class DetectNewArrivalsChange < Base
        def self.interval_seconds
          4
        end

        def perform
          response = RestClient.post("#{base_url}/service/product/list", list_payload.to_json, request_headers)
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          products = parsed_body.dig(:data, :list)
          products&.each do |product|
            product_sizes = get_variant_sizes(product)
            product_variant = product[:variantList].first
            product_name = "#{product[:name]} - #{product_variant&.dig(:name)}"
            product_img = product_variant&.dig(:featuredImage)
            product_img = "#{base_url}/assets/upload/full/#{product_img}" if product_img.present?
            product_slug = product.dig(:permalink)
            product_url = "#{base_url}/product/details/#{product_slug}"

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

        def get_variant_sizes(product)
          product_variant = product[:variantList].first
          variant_sizes_response = RestClient.post(
            "#{base_url}/service/product/variant/available/sizes",
            variant_size_payload(product_variant[:id]).to_json,
            request_headers
          )
          variant_sizes = JSON.parse(variant_sizes_response.body).deep_symbolize_keys
          product_sizes = []
          product_label_size = product.dig(:brandSize, :mainLabelSize)
          variant_sizes.dig(:data)&.each do |variant_size|
            product_sizes << {
              id: variant_size[:id],
              size: variant_size[:sizeName],
              description: "#{product_label_size} #{variant_size[:sizeName]}",
              quantity: variant_size[:quantity]
            } if variant_size[:quantity].to_i > 0
          end

          product_sizes
        end

        def list_payload
          {
            :pageType => 'NEW_ARRIVAL',
            :categories => [12],
            :sort => 'NEW_ARRIVAL',
            :limit => 30,
            :offset => 0,
            :minPrice => 65_000,
            :maxPrice => 20_000_000
          }
        end

        def variant_size_payload(variant_id)
          { variantId: variant_id.to_i }
        end

        def request_headers
          # TODO: create a user agent strings pool and randomized from there
          {
            content_type: :json,
            accept: :json,
            user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15 Version/13.0.4'
          }
        end

        def whitelisted_products
          @whitelisted_products ||= ENV['SEEK_INDONESIA_LATEST_WHITELISTED_PRODUCTS'].split(",")
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
          prefix = "seek_indonesia_new_arrivals"
          "#{prefix}_#{identifier.downcase}"
        end

        def send_message(product_hash)
          message = "<strong>SEEK INDONESIA NEW ARRIVALS UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"

          message += "\n\n<strong>AVAILABLE SIZE</strong>:\n" if product_hash[:sizes].present?
          product_hash[:sizes].each { |size| message += "<strong>#{size[:description]}</strong> -- #{size[:quantity]} PCS\n" }
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def base_url
          ENV['SEEK_INDONESIA_BASE_URL']
        end
      end
    end
  end
end
