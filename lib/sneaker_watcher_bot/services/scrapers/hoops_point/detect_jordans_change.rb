module Service
  module Scraper
    module HoopsPoint
      class DetectJordansChange < Base
        def perform
          response = RestClient.get("#{base_url}/api/products/categories")
          parsed_body = JSON.parse(response.body).map(&:deep_symbolize_keys)
          jordans = parsed_body.select { |c| c[:Slug] == 'jordan-shoes' }.first[:Products]
          jordans.each do |jordan|
            begin
              product_slug = jordan[:Slug]
              product_url = "#{base_url}/store/product/#{product_slug}"
              product_name = jordan[:Name]
              product_img = "#{base_url}#{jordan[:Thumbnail].first}"
              product_hash = {
                slug: product_slug,
                name: product_name,
                url: product_url,
                image: product_img
              }
              sizes = available_sizes(product_slug)
              next if sizes.blank? || !new_product?(product_slug)
              send_message(product_hash, sizes)
            rescue
              # TODO: Log the error rescued
            end
          end
        end

        private

        def available_sizes(product_slug)
          detail_product_response = RestClient.get("#{base_url}/api/products/#{product_slug}")
          product = JSON.parse(detail_product_response.body).deep_symbolize_keys
          sizes = product[:Options].select do |o| 
            o[:Title].downcase.gsub(/[^0-9a-z ]/i, '') == 'size'
          end.first[:Options]
          sizes.each_with_object([]) do |size, available|
            next if size[:Quantity] == 0
            available << {
              value: size[:Value],
              quantity: size[:Quantity].to_i
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
          message = "*HOOPS POINT JORDANS UPDATE DETECTED!*\n"\
            "#{product_hash[:name]}\n"\
            "[CHECK IT OUT!](#{product_hash[:url]})"
          message += "\n\n*AVAILABLE SIZE*:"
          sizes.each do |size|
            next if size[:quantity] == 0
            message += "\n*US #{size[:value]}* -- #{size[:quantity]} PCS"
          end
          TelegramBot.new.send_telegram_photo(message, product_hash[:image])
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def redis_key(identifier)
          "hoops_point_latest_jordans_#{identifier}"
        end

        def base_url
          ENV['HOOPS_POINT_BASE_URL']
        end
      end
    end
  end
end