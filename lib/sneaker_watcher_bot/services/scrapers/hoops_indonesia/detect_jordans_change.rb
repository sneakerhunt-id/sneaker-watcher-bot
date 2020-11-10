module Service
  module Scraper
    module HoopsIndonesia
      class DetectJordansChange < Base
        def perform
          payload = {
            parent_id: '5', # BRAND
            sub_id: '13' # JORDAN
          }
          response = RestClient.post("#{api_url}/cms/product/v2/category/1/12?sort=id&order=DESC", payload.to_json, {content_type: :json, accept: :json})
          parsed_body = JSON.parse(response.body).deep_symbolize_keys
          jordans = parsed_body.dig(:body, :data)
          jordans.each do |jordan|
            begin
              product_id = jordan[:id]
              product_url = "#{base_url}/detail/?id=#{product_id}"
              product_name = jordan[:name]
              product_img = jordan[:images_group].first[:imageUrl]
              product_hash = {
                id: product_id,
                name: product_name,
                url: product_url,
                image: product_img
              }
              sizes = available_sizes(jordan)
              next if sizes.blank? || # no size available (sold out)
                !relevant_product?(product_name) || # not relevant
                !new_product?(product_id) # not a new product
              send_message(product_hash, sizes)
            rescue
              # TODO: Log the error rescued
            end
          end
        end

        private

        def whitelisted_products
          ['air jordan']
        end

        def available_sizes(jordan)
          sizes = jordan.dig(:size_quantity) || []
          sizes.each_with_object([]) do |size, available|
            next if size[:quantity] == 0
            available << {
              value: size[:size],
              quantity: size[:quantity].to_i
            }
          end
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

        def send_message(product_hash, sizes)
          message = "<strong>HOOPS INDONESIA JORDANS UPDATE DETECTED!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>"
          message += "\n\n<strong>AVAILABLE SIZE</strong>:"
          # sizes.sort_by! { |s| s[:value]}
          sizes.each do |size|
            next if size[:quantity] == 0
            message += "\n<strong>US #{size[:value]}</strong> -- #{size[:quantity]} PCS"
          end
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:id]), product_hash.to_json)
        end

        def redis_key(identifier)
          "hoops_indonesia_latest_jordans_#{identifier}"
        end

        def base_url
          ENV['HOOPS_INDONESIA_BASE_URL']
        end

        def api_url
          ENV['HOOPS_INDONESIA_API_URL']
        end
      end
    end
  end
end