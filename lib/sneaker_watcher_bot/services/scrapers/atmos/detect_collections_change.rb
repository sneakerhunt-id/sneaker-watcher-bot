module Service
  module Scraper
    module Atmos
      class DetectCollectionsChange < Base
        def self.interval_seconds
          5
        end

        def perform
          response = RestClient.get("#{base_url}/collections")
          html = Nokogiri::HTML(response.body)
          html.xpath("//*[@id='panel']//div//a//img").each do |img|
            begin
              product_sold_out = img.parent.parent.xpath(".//*[contains(text(),'sold')]")
              product_url = img.parent.attributes['href'].value
              product_name = img.attributes['alt'].value
              product_img = img.attributes['src'].value
              product_img = "https:#{product_img}"
              product_hash = {
                name: product_name,
                url: product_url,
                image: product_img
              }
              next if raffle?(product_url) || # is a raffle
                product_sold_out.present? || # already sold out
                !relevant_product?(product_name) # not relevant

              product_detail = get_product_detail(product_url)
              product_hash.merge!(product_detail)

              next if raffle?(product_hash[:tags]) || # is a raffle
                !new_product?(product_hash) # not a new product

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
          "atmos_latest_collections_#{identifier}"
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
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), product_hash.to_json)
        end

        def get_product_detail(product_url)
          response = RestClient.get("#{base_url}#{product_url}.json")
          raw_product_data = JSON.parse(response.body).deep_symbolize_keys
          sizes = []
          raw_product_data.dig(:product, :variants).each do |variant|
            sizes << {
              id: variant[:id],
              title: variant[:option1]
            }
          end
          {
            slug: raw_product_data.dig(:product, :handle),
            tags: raw_product_data.dig(:product, :tags),
            sizes: sizes
          }
        end
      end
    end
  end
end
