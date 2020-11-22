module Service
  module Scraper
    module Nike
      class DetectSnkrsReminder < Base
        def self.interval_seconds
          60
        end

        def perform
          SneakerWatcherBot.redis.scan_each(match: 'nike_snkrs_web*') do |key|
            product = SneakerWatcherBot.redis.get(key)
            next if product.blank?
            product_hash = JSON.parse(product).deep_symbolize_keys
            next if past_release?(product_hash[:release_time]) ||
              !reminder_time?(product_hash[:release_time]) ||
              !new_product?(product_hash[:slug])
            send_message(product_hash)
          end
        end

        private

        def past_release?(product_release_time)
          Time.parse(product_release_time) < Time.now
        end

        def reminder_time?(product_release_time)
          need_reminder_seconds = ENV.fetch('NIKE_SNKRS_REMINDER_HOUR', 2).to_i * 3600
          product_release_time = Time.parse(product_release_time)
          seconds_until_release = (product_release_time - Time.now).abs.to_i
          # if not released yet and already 12 hours (configurable) prior to release
          product_release_time > Time.now && seconds_until_release <= need_reminder_seconds
        end

        def new_product?(identifier)
          key = redis_key(identifier)
          product_cache = SneakerWatcherBot.redis.get(key)
          return true if product_cache.blank?
          SneakerWatcherBot.redis.expireat(key, redis_expiry.to_i)
          return false
        end

        def redis_expiry
          Time.now + 8.hours
        end

        def send_message(product_hash)
          message = "<strong>NIKE SNKRS RELEASE REMINDER!</strong>\n"\
            "#{product_hash[:name]}\n"\
            "<a href='#{product_hash[:url]}'>CHECK IT OUT!</a>\n\n"\
            "RELEASE SOON:\n#{Time.parse(product_hash[:release_time]).in_time_zone("Jakarta").strftime('%d %B %Y at %H:%M WIB')}\n\n"\
            "AVAILABLE SIZE:\n"
          product_id = ''
          product_hash.dig(:sizes)&.each do |size|
            if size[:id] != product_id
              message += "\n"
              product_id = size[:id]
            end
            early_checkout_link = "#{web_base_url}/t/#{product_hash[:slug]}?"\
              "size=#{size[:size]}&"\
              "productId=#{product_id}"
            message += "<strong>#{size[:description]}</strong> "\
              "<a href='#{early_checkout_link}'>CHECKOUT</a>\n"\
          end
          TelegramBot.new.send_telegram_photo(nil, product_hash[:image])
          TelegramBot.new.send_telegram_message(message)
          SneakerWatcherBot.redis.set(redis_key(product_hash[:slug]), true)
        end

        def redis_key(identifier)
          "nike_snkrs_reminder_#{identifier.downcase}"
        end

        def web_base_url
          ENV['NIKE_SNKRS_WEB_BASE_URL']
        end
      end
    end
  end
end
